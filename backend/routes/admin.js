const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { createNotification } = require('../utils/notifications');
const { emitBusinessUpdate } = require('../utils/business_updates');

const router = express.Router();
const BUSINESS_CATEGORIES = new Set(['bakery', 'barber', 'restaurant', 'clinic', 'bank', 'repair', 'beauty', 'dentist', 'gym', 'pharmacy', 'grocery', 'government', 'cafe', 'vet', 'other']);
const SERVICE_TYPES = new Set(['queue', 'appointment', 'both']);
const APPROVAL_STATUSES = new Set(['pending', 'approved', 'rejected']);

// Middleware: require admin role
function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin access required' });
  next();
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

async function emitQueueUpdate(io, businessId) {
  if (!io || !businessId) return;

  const [queueRows] = await pool.query('SELECT * FROM queues WHERE business_id = ?', [businessId]);
  const [entries] = await pool.query(
    "SELECT * FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') ORDER BY position ASC",
    [businessId]
  );

  io.to(`business:${businessId}`).emit('queue:update', {
    queue: queueRows[0] || null,
    entries,
  });
}

// ─── DASHBOARD ──────────────────────────────────────────
router.get('/dashboard', authenticate, requireAdmin, async (req, res) => {
  try {
    const [[{ totalUsers }]] = await pool.query("SELECT COUNT(*) as totalUsers FROM users WHERE role != 'admin'");
    const [[{ totalBusinesses }]] = await pool.query('SELECT COUNT(*) as totalBusinesses FROM businesses');
    const [[{ totalCustomers }]] = await pool.query("SELECT COUNT(*) as totalCustomers FROM users WHERE role = 'customer'");
    const [[{ pendingBusinesses }]] = await pool.query("SELECT COUNT(*) as pendingBusinesses FROM businesses WHERE approval_status = 'pending'");
    const [[{ activeQueues }]] = await pool.query("SELECT COALESCE(SUM(waiting_count),0) as activeQueues FROM queues WHERE is_open = 1");
    const [[{ todayAppointments }]] = await pool.query("SELECT COUNT(*) as todayAppointments FROM appointments WHERE DATE(date_time) = CURDATE()");
    const [[{ openTickets }]] = await pool.query("SELECT COUNT(*) as openTickets FROM tickets WHERE status IN ('open','in_progress')");
    const [[{ bannedUsers }]] = await pool.query('SELECT COUNT(*) as bannedUsers FROM users WHERE is_banned = 1');

    // Growth: new users last 30 days
    const [userGrowthRows] = await pool.query(
      `SELECT DATE(created_at) as day, COUNT(*) as count FROM users
       WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 29 DAY) AND role != 'admin'
       GROUP BY DATE(created_at) ORDER BY day`
    );

    // Growth: new businesses last 30 days
    const [bizGrowthRows] = await pool.query(
      `SELECT DATE(created_at) as day, COUNT(*) as count FROM businesses
       WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 29 DAY)
       GROUP BY DATE(created_at) ORDER BY day`
    );

    const [hourlyHeatmap] = await pool.query(
      `SELECT weekday, hour, SUM(activity_count) as count
       FROM (
         SELECT WEEKDAY(joined_at) as weekday, HOUR(joined_at) as hour, COUNT(*) as activity_count
         FROM queue_entries
         WHERE joined_at BETWEEN DATE_SUB(NOW(), INTERVAL 28 DAY) AND NOW()
         GROUP BY WEEKDAY(joined_at), HOUR(joined_at)

         UNION ALL

         SELECT WEEKDAY(date_time) as weekday, HOUR(date_time) as hour, COUNT(*) as activity_count
         FROM appointments
         WHERE date_time BETWEEN DATE_SUB(NOW(), INTERVAL 28 DAY) AND NOW()
           AND status != 'cancelled'
         GROUP BY WEEKDAY(date_time), HOUR(date_time)
       ) hourly_activity
       GROUP BY weekday, hour
       ORDER BY weekday ASC, hour ASC`
    );

    const [[noShowStats]] = await pool.query(
      `SELECT
         SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as no_show_count,
         SUM(CASE WHEN status IN ('done', 'cancelled') THEN 1 ELSE 0 END) as resolved_count
       FROM queue_entries
       WHERE joined_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)`
    );

    // Popularity by category based on completed queue and appointment operations.
    const [categoryPopularity] = await pool.query(
      `SELECT category as name, SUM(activity_count) as count
       FROM (
         SELECT b.category as category, COUNT(*) as activity_count
         FROM queue_entries qe
         JOIN businesses b ON b.id = qe.business_id
         WHERE qe.status = 'done'
         GROUP BY b.category

         UNION ALL

         SELECT b.category as category, COUNT(*) as activity_count
         FROM appointments a
         JOIN businesses b ON b.id = a.business_id
         WHERE a.status = 'completed'
         GROUP BY b.category
       ) category_activity
       GROUP BY category
       ORDER BY count DESC`
    );

    const noShowCount = Number(noShowStats?.no_show_count || 0);
    const resolvedCount = Number(noShowStats?.resolved_count || 0);
    const noShowRate = resolvedCount > 0 ? Number(((noShowCount / resolvedCount) * 100).toFixed(1)) : 0;

    const formatGrowth = (rows) => {
      const countsByDay = new Map(
        rows.map((row) => [new Date(row.day).toISOString().slice(0, 10), Number(row.count || 0)])
      );

      return Array.from({ length: 30 }, (_, index) => {
        const date = new Date();
        date.setHours(0, 0, 0, 0);
        date.setDate(date.getDate() - (29 - index));
        const key = date.toISOString().slice(0, 10);
        return {
          day: key,
          count: countsByDay.get(key) || 0,
        };
      });
    };

    res.json({
      totalUsers, totalBusinesses, totalCustomers, pendingBusinesses,
      activeQueues, todayAppointments, openTickets, bannedUsers,
      userGrowth: formatGrowth(userGrowthRows),
      bizGrowth: formatGrowth(bizGrowthRows),
      hourlyHeatmap: hourlyHeatmap.map((row) => ({
        weekday: Number(row.weekday || 0),
        hour: Number(row.hour || 0),
        count: Number(row.count || 0),
      })),
      noShowCount,
      resolvedQueueEntries: resolvedCount,
      noShowRate,
      categoryPopularity,
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── USERS ──────────────────────────────────────────────
router.get('/users', authenticate, requireAdmin, async (req, res) => {
  const { role, search, page = 1, limit = 20 } = req.query;
  const offset = (Math.max(1, +page) - 1) * Math.min(50, Math.max(1, +limit));
  try {
    let where = "WHERE role != 'admin'";
    const params = [];
    if (role) { where += ' AND role = ?'; params.push(role); }
    if (search) { where += ' AND (name LIKE ? OR email LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }

    const [[{ total }]] = await pool.query(`SELECT COUNT(*) as total FROM users ${where}`, params);
    const [rows] = await pool.query(
      `SELECT id, name, email, phone, role, is_banned, ban_reason, created_at FROM users ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [...params, +limit, offset]
    );
    res.json({ users: rows, total, page: +page, totalPages: Math.ceil(total / limit) });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/users/:id/ban', authenticate, requireAdmin, async (req, res) => {
  const { reason } = req.body;
  try {
    await pool.query('UPDATE users SET is_banned = 1, ban_reason = ? WHERE id = ?', [reason || 'Policy violation', req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/users/:id/unban', authenticate, requireAdmin, async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_banned = 0, ban_reason = NULL WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.delete('/users/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    await pool.query('DELETE FROM businesses WHERE owner_id = ?', [req.params.id]);
    await pool.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── BUSINESSES ─────────────────────────────────────────
router.get('/businesses', authenticate, requireAdmin, async (req, res) => {
  const { status, search, category, page = 1, limit = 20 } = req.query;
  const offset = (Math.max(1, +page) - 1) * Math.min(50, Math.max(1, +limit));
  try {
    let where = 'WHERE 1=1';
    const params = [];
    if (status) { where += ' AND b.approval_status = ?'; params.push(status); }
    if (category && BUSINESS_CATEGORIES.has(category)) { where += ' AND b.category = ?'; params.push(category); }
    if (search) { where += ' AND (b.name LIKE ? OR u.name LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }

    const [[{ total }]] = await pool.query(`SELECT COUNT(*) as total FROM businesses b JOIN users u ON b.owner_id = u.id ${where}`, params);
    const [rows] = await pool.query(
      `SELECT b.*, u.name as owner_name, u.email as owner_email, u.is_banned as owner_banned
       FROM businesses b JOIN users u ON b.owner_id = u.id ${where}
       ORDER BY b.created_at DESC LIMIT ? OFFSET ?`,
      [...params, +limit, offset]
    );
    res.json({ businesses: rows, total, page: +page, totalPages: Math.ceil(total / limit) });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/businesses/:id/approve', authenticate, requireAdmin, async (req, res) => {
  try {
    const [businessRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    await pool.query("UPDATE businesses SET approval_status = 'approved', is_active = 1 WHERE id = ?", [req.params.id]);
    if (businessRows[0]?.owner_id) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: businessRows[0].owner_id,
        title: 'Business approved',
        body: `${businessRows[0].name || 'Your business'} is now approved and visible to customers.`,
        type: 'business_approved',
        entityType: 'business',
        entityId: req.params.id,
      });
    }
    const [updatedRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    await emitBusinessUpdate({ io: req.app.get('io'), business: updatedRows[0] });
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/businesses/:id/reject', authenticate, requireAdmin, async (req, res) => {
  try {
    const [businessRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    await pool.query("UPDATE businesses SET approval_status = 'rejected', is_active = 0 WHERE id = ?", [req.params.id]);
    if (businessRows[0]?.owner_id) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: businessRows[0].owner_id,
        title: 'Business review update',
        body: `${businessRows[0].name || 'Your business'} was not approved. Please review your details and try again.`,
        type: 'business_rejected',
        entityType: 'business',
        entityId: req.params.id,
      });
    }
    const [updatedRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    await emitBusinessUpdate({ io: req.app.get('io'), business: updatedRows[0] });
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/businesses/:id', authenticate, requireAdmin, async (req, res) => {
  const {
    name,
    description,
    address,
    phone,
    category,
    service_type,
    is_active,
    approval_status,
  } = req.body || {};

  if (category != null && !BUSINESS_CATEGORIES.has(category)) {
    return res.status(400).json({ error: 'Invalid business category' });
  }
  if (service_type != null && !SERVICE_TYPES.has(service_type)) {
    return res.status(400).json({ error: 'Invalid service type' });
  }
  if (approval_status != null && !APPROVAL_STATUSES.has(approval_status)) {
    return res.status(400).json({ error: 'Invalid approval status' });
  }

  try {
    const [existingRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    if (existingRows.length === 0) return res.status(404).json({ error: 'Business not found' });

    const existing = existingRows[0];
    await pool.query(
      `UPDATE businesses
       SET name = ?, description = ?, address = ?, phone = ?, category = ?, service_type = ?, is_active = ?, approval_status = ?
       WHERE id = ?`,
      [
        (name ?? existing.name)?.toString().trim() || existing.name,
        description ?? existing.description,
        address ?? existing.address,
        phone ?? existing.phone,
        category ?? existing.category,
        service_type ?? existing.service_type,
        is_active == null ? existing.is_active : (is_active ? 1 : 0),
        approval_status ?? existing.approval_status,
        req.params.id,
      ]
    );

    const [rows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    await emitBusinessUpdate({ io: req.app.get('io'), business: rows[0] });
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: get business detail with products, slots, queue
router.get('/businesses/:id/detail', authenticate, requireAdmin, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    if (biz.length === 0) return res.status(404).json({ error: 'Business not found' });
    const [products] = await pool.query('SELECT * FROM products WHERE business_id = ? ORDER BY name', [req.params.id]);
    const [slots] = await pool.query('SELECT * FROM time_slots WHERE business_id = ? ORDER BY start_time', [req.params.id]);
    const [queue] = await pool.query('SELECT * FROM queues WHERE business_id = ?', [req.params.id]);
    const [queueEntries] = await pool.query(
      `SELECT qe.*, u.name as customer_name FROM queue_entries qe
       LEFT JOIN users u ON qe.customer_id = u.id
       WHERE qe.business_id = ? AND qe.status IN ('waiting','serving')
       ORDER BY qe.position ASC`,
      [req.params.id]
    );
    const [appointments] = await pool.query(
      `SELECT a.*, p.price AS original_price, p.duration_minutes AS service_duration_minutes
       FROM appointments a
       LEFT JOIN products p ON p.business_id = a.business_id AND p.name = a.service_name
       WHERE a.business_id = ? AND a.status IN ('pending','confirmed')
       ORDER BY a.date_time ASC`,
      [req.params.id]
    );
    res.json({ business: biz[0], products, slots, queue: queue[0] || null, queueEntries, appointments });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: update product
router.put('/products/:id', authenticate, requireAdmin, async (req, res) => {
  const { name, price, duration_minutes, stock, is_available, is_off_sale } = req.body;
  try {
    await pool.query(
      'UPDATE products SET name=?, price=?, duration_minutes=?, stock=?, is_available=?, is_off_sale=? WHERE id=?',
      [name, price, duration_minutes, stock, is_available ? 1 : 0, is_off_sale ? 1 : 0, req.params.id]
    );
    const [productRows] = await pool.query('SELECT * FROM products WHERE id = ?', [req.params.id]);
    if (productRows[0]?.business_id) {
      req.app.get('io')?.to(`business:${productRows[0].business_id}`).emit('product:update', {
        businessId: productRows[0].business_id,
        productId: req.params.id,
        action: 'updated',
        product: productRows[0],
        updatedAt: new Date().toISOString(),
      });
    }
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/businesses/:id/queue/reorder', authenticate, requireAdmin, async (req, res) => {
  const orderedEntryIds = Array.isArray(req.body?.orderedEntryIds) ? req.body.orderedEntryIds : [];
  if (orderedEntryIds.length === 0) return res.status(400).json({ error: 'orderedEntryIds required' });

  try {
    const [activeRows] = await pool.query(
      "SELECT id, status FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') ORDER BY position ASC",
      [req.params.id]
    );
    if (activeRows.length === 0) return res.status(404).json({ error: 'No active queue entries found' });

    const waitingRows = activeRows.filter((row) => row.status === 'waiting');
    const servingRows = activeRows.filter((row) => row.status === 'serving');
    if (waitingRows.length !== orderedEntryIds.length) {
      return res.status(400).json({ error: 'orderedEntryIds must include all waiting entries' });
    }

    const waitingIds = waitingRows.map((row) => row.id).sort();
    const incomingIds = orderedEntryIds.map((id) => id.toString()).sort();
    if (waitingIds.join(',') != incomingIds.join(',')) {
      return res.status(400).json({ error: 'orderedEntryIds do not match current waiting entries' });
    }

    const finalOrder = [...servingRows.map((row) => row.id), ...orderedEntryIds.map((id) => id.toString())];
    for (let index = 0; index < finalOrder.length; index += 1) {
      await pool.query('UPDATE queue_entries SET position = ? WHERE id = ?', [index + 1, finalOrder[index]]);
    }

    await emitQueueUpdate(req.app.get('io'), req.params.id);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin: swap queue positions
router.post('/queue-entries/swap', authenticate, requireAdmin, async (req, res) => {
  const { entryId1, entryId2 } = req.body;
  if (!entryId1 || !entryId2) return res.status(400).json({ error: 'Two entry IDs required' });
  try {
    const [e1] = await pool.query('SELECT id, position FROM queue_entries WHERE id = ?', [entryId1]);
    const [e2] = await pool.query('SELECT id, position FROM queue_entries WHERE id = ?', [entryId2]);
    if (e1.length === 0 || e2.length === 0) return res.status(404).json({ error: 'Entry not found' });
    await pool.query('UPDATE queue_entries SET position = ? WHERE id = ?', [e2[0].position, entryId1]);
    await pool.query('UPDATE queue_entries SET position = ? WHERE id = ?', [e1[0].position, entryId2]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── CATEGORIES ─────────────────────────────────────────
router.get('/categories', authenticate, requireAdmin, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM categories ORDER BY sort_order ASC');
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/categories', authenticate, requireAdmin, async (req, res) => {
  const { name, display_name, icon } = req.body;
  if (!name || !display_name) return res.status(400).json({ error: 'Name and display_name required' });
  try {
    const id = uuidv4();
    const [[{ maxOrder }]] = await pool.query('SELECT COALESCE(MAX(sort_order),0) as maxOrder FROM categories');
    await pool.query('INSERT INTO categories (id, name, display_name, icon, sort_order) VALUES (?,?,?,?,?)',
      [id, name.toLowerCase().replace(/\s+/g, '_'), display_name, icon || 'store', maxOrder + 1]);
    res.json({ id, name, display_name, icon: icon || 'store', sort_order: maxOrder + 1 });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/categories/:id', authenticate, requireAdmin, async (req, res) => {
  const { display_name, icon, is_active, sort_order } = req.body;
  try {
    await pool.query('UPDATE categories SET display_name=?, icon=?, is_active=?, sort_order=? WHERE id=?',
      [display_name, icon, is_active ? 1 : 0, sort_order, req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.delete('/categories/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    await pool.query('DELETE FROM categories WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── TICKETS ────────────────────────────────────────────
router.get('/tickets', authenticate, requireAdmin, async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;
  const offset = (Math.max(1, +page) - 1) * Math.min(50, Math.max(1, +limit));
  try {
    let where = 'WHERE 1=1';
    const params = [];
    if (status) { where += ' AND t.status = ?'; params.push(status); }

    const [[{ total }]] = await pool.query(`SELECT COUNT(*) as total FROM tickets t ${where}`, params);
    const [rows] = await pool.query(
      `SELECT t.*, u.name as user_name, u.email as user_email, u.role as user_role
       FROM tickets t JOIN users u ON t.user_id = u.id ${where}
       ORDER BY t.updated_at DESC, t.created_at DESC LIMIT ? OFFSET ?`,
      [...params, +limit, offset]
    );
    res.json({ tickets: rows, total, page: +page, totalPages: Math.ceil(total / limit) });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/tickets/:id/messages', authenticate, requireAdmin, async (req, res) => {
  try {
    const [ticket] = await pool.query(
      `SELECT t.*, u.name as user_name, u.email as user_email FROM tickets t JOIN users u ON t.user_id = u.id WHERE t.id = ?`,
      [req.params.id]
    );
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

router.post('/tickets/:id/reply', authenticate, requireAdmin, async (req, res) => {
  const { message } = req.body;
  if (!message || !message.trim()) return res.status(400).json({ error: 'Message required' });
  try {
    const [ticket] = await pool.query('SELECT id, user_id, status FROM tickets WHERE id = ?', [req.params.id]);
    if (ticket.length === 0) return res.status(404).json({ error: 'Ticket not found' });

    const nextStatus = 'in_progress';

    const id = uuidv4();
    await pool.query('INSERT INTO ticket_messages (id, ticket_id, sender_id, message, is_admin) VALUES (?,?,?,?,1)',
      [id, req.params.id, req.user.id, message.trim()]);
    await pool.query('UPDATE tickets SET status = ?, updated_at = NOW() WHERE id = ?', [nextStatus, req.params.id]);
    await createNotification({
      pool,
      io: req.app.get('io'),
      userId: ticket[0].user_id,
      title: 'New support reply',
      body: message.trim(),
      type: 'ticket_admin_reply',
      entityType: 'ticket',
      entityId: req.params.id,
      metadata: { ticketId: req.params.id },
    });
    emitTicketUpdate(req.app.get('io'), {
      ticketId: req.params.id,
      userId: ticket[0].user_id,
      status: nextStatus,
      type: 'message',
    });
    res.json({ success: true, id });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.put('/tickets/:id/status', authenticate, requireAdmin, async (req, res) => {
  const { status } = req.body;
  if (!['open','in_progress','resolved','closed'].includes(status)) return res.status(400).json({ error: 'Invalid status' });
  try {
    const [ticket] = await pool.query('SELECT id, user_id FROM tickets WHERE id = ?', [req.params.id]);
    if (ticket.length === 0) return res.status(404).json({ error: 'Ticket not found' });

    await pool.query('UPDATE tickets SET status = ?, updated_at = NOW() WHERE id = ?', [status, req.params.id]);
    await createNotification({
      pool,
      io: req.app.get('io'),
      userId: ticket[0].user_id,
      title: 'Support ticket status changed',
      body: `Your support ticket is now ${status.replaceAll('_', ' ')}.`,
      type: 'ticket_status',
      entityType: 'ticket',
      entityId: req.params.id,
      metadata: { ticketId: req.params.id, status },
    });
    emitTicketUpdate(req.app.get('io'), {
      ticketId: req.params.id,
      userId: ticket[0].user_id,
      status,
      type: 'status',
    });
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── FRAUD LOGS ─────────────────────────────────────────
router.get('/fraud-logs', authenticate, requireAdmin, async (req, res) => {
  const { page = 1, limit = 30 } = req.query;
  const offset = (Math.max(1, +page) - 1) * Math.min(50, Math.max(1, +limit));
  try {
    // Auto-detect: users who joined queue 3+ times without completing
    const [noShows] = await pool.query(
      `SELECT u.id as user_id, u.name, u.email, COUNT(*) as cancel_count, 'frequent_cancellation' as event_type
       FROM queue_entries qe JOIN users u ON qe.customer_id = u.id
       WHERE qe.status = 'cancelled' AND qe.joined_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
       GROUP BY u.id HAVING cancel_count >= 3
       ORDER BY cancel_count DESC LIMIT 20`
    );

    // Manual logs
    const [[{ total }]] = await pool.query('SELECT COUNT(*) as total FROM fraud_logs');
    const [logs] = await pool.query(
      `SELECT fl.*, u.name as user_name, b.name as business_name
       FROM fraud_logs fl
       LEFT JOIN users u ON fl.user_id = u.id
       LEFT JOIN businesses b ON fl.business_id = b.id
       ORDER BY fl.created_at DESC LIMIT ? OFFSET ?`,
      [+limit, offset]
    );
    res.json({ autoDetected: noShows, manualLogs: logs, total });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
