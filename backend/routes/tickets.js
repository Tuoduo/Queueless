const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { notifyAdmins } = require('../utils/notifications');

const router = express.Router();

const TICKET_CATEGORY_ALIASES = {
  bug: 'bug',
  complaint: 'complaint',
  suggestion: 'suggestion',
  account: 'account',
  other: 'other',
  technical: 'bug',
  billing: 'complaint',
  feedback: 'suggestion',
  general: 'other',
};

function normalizeTicketCategory(category) {
  const normalized = String(category || '').trim().toLowerCase().replace(/\s+/g, '_');
  return TICKET_CATEGORY_ALIASES[normalized] || 'other';
}

function emitTicketUpdate(io, { ticketId, userId, status, type }) {
  if (!io || !ticketId || !userId) return;

  const payload = {
    ticketId,
    userId,
    status,
    type,
    updatedAt: new Date().toISOString(),
  };

  io.to('admin:panel').emit('ticket:update', payload);
  io.to(`user:${userId}`).emit('ticket:update', payload);
}

async function reopenTicketIfClosed(ticketId, nextStatus) {
  await pool.query('UPDATE tickets SET status = ?, updated_at = NOW() WHERE id = ?', [nextStatus, ticketId]);
}

// POST /api/tickets — create a new ticket
router.post('/', authenticate, async (req, res) => {
  const { subject, category, message } = req.body;
  if (!subject || !message) return res.status(400).json({ error: 'Subject and message are required' });

  try {
    const ticketId = uuidv4();
    const messageId = uuidv4();
    const normalizedCategory = normalizeTicketCategory(category);
    await pool.query(
      'INSERT INTO tickets (id, user_id, subject, category) VALUES (?,?,?,?)',
      [ticketId, req.user.id, subject.trim(), normalizedCategory]
    );
    await pool.query(
      'INSERT INTO ticket_messages (id, ticket_id, sender_id, message, is_admin) VALUES (?,?,?,?,0)',
      [messageId, ticketId, req.user.id, message.trim()]
    );
    await notifyAdmins({
      pool,
      io: req.app.get('io'),
      title: 'New support ticket',
      body: `${subject.trim()} needs an admin response.`,
      type: 'ticket_created',
      entityType: 'ticket',
      entityId: ticketId,
      metadata: { ticketId, userId: req.user.id },
    });
    emitTicketUpdate(req.app.get('io'), {
      ticketId,
      userId: req.user.id,
      status: 'open',
      type: 'created',
    });
    res.status(201).json({ id: ticketId, subject: subject.trim(), category: normalizedCategory, status: 'open' });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/tickets/mine — list my tickets
router.get('/mine', authenticate, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM tickets WHERE user_id = ? ORDER BY updated_at DESC',
      [req.user.id]
    );
    res.json({ tickets: rows });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/tickets/:id — get ticket detail with messages
router.get('/:id', authenticate, async (req, res) => {
  try {
    const [ticket] = await pool.query('SELECT * FROM tickets WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    if (ticket.length === 0) return res.status(404).json({ error: 'Ticket not found' });
    const [messages] = await pool.query(
      `SELECT tm.*, u.name as sender_name,
              CASE WHEN tm.is_admin = 1 THEN 'admin' ELSE 'user' END as sender_role
       FROM ticket_messages tm
       JOIN users u ON tm.sender_id = u.id
       WHERE tm.ticket_id = ?
       ORDER BY tm.created_at ASC`,
      [req.params.id]
    );
    res.json({ ticket: ticket[0], messages });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/tickets/:id/message — add a message to own ticket
router.post('/:id/message', authenticate, async (req, res) => {
  const { message } = req.body;
  if (!message || !message.trim()) return res.status(400).json({ error: 'Message required' });
  try {
    const [ticket] = await pool.query('SELECT id, status FROM tickets WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    if (ticket.length === 0) return res.status(404).json({ error: 'Ticket not found' });

    const nextStatus = ticket[0].status === 'closed' ? 'open' : ticket[0].status;

    const id = uuidv4();
    await pool.query('INSERT INTO ticket_messages (id, ticket_id, sender_id, message, is_admin) VALUES (?,?,?,?,0)',
      [id, req.params.id, req.user.id, message.trim()]);
    await reopenTicketIfClosed(req.params.id, nextStatus);
    await notifyAdmins({
      pool,
      io: req.app.get('io'),
      title: 'Customer replied to a support ticket',
      body: message.trim(),
      type: 'ticket_customer_reply',
      entityType: 'ticket',
      entityId: req.params.id,
      metadata: { ticketId: req.params.id, userId: req.user.id },
    });
    emitTicketUpdate(req.app.get('io'), {
      ticketId: req.params.id,
      userId: req.user.id,
      status: nextStatus,
      type: 'message',
    });
    res.json({ success: true, id });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
