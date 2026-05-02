const express = require('express');
const { v4: uuidv4 } = require('uuid');

const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { createNotification } = require('../utils/notifications');

const router = express.Router();

function getSenderRole(userRole) {
  return userRole === 'businessOwner' ? 'businessOwner' : 'customer';
}

function decorateConversation(conversation) {
  if (!conversation) return null;

  return {
    ...conversation,
    is_banned: conversation.is_banned === 1 || conversation.is_banned === true,
  };
}

async function getChatBan(businessId, customerId) {
  const [rows] = await pool.query(
    `SELECT id, business_id, customer_id, owner_id, reason, created_at
     FROM business_chat_bans
     WHERE business_id = ? AND customer_id = ?`,
    [businessId, customerId]
  );
  return rows[0] || null;
}

async function getConversationById(conversationId) {
  const [rows] = await pool.query(
    `SELECT c.*, b.name as business_name, u.name as customer_name, o.name as owner_name,
            cb.id as ban_id, cb.reason as ban_reason, cb.created_at as banned_at,
            CASE WHEN cb.id IS NULL THEN 0 ELSE 1 END as is_banned
     FROM business_chat_conversations c
     JOIN businesses b ON b.id = c.business_id
     JOIN users u ON u.id = c.customer_id
     JOIN users o ON o.id = c.owner_id
     LEFT JOIN business_chat_bans cb ON cb.business_id = c.business_id AND cb.customer_id = c.customer_id
     WHERE c.id = ?`,
    [conversationId]
  );

  return decorateConversation(rows[0] || null);
}

async function getConversationMessages(conversationId) {
  const [rows] = await pool.query(
    `SELECT m.*, u.name as sender_name
     FROM business_chat_messages m
     JOIN users u ON u.id = m.sender_id
     WHERE m.conversation_id = ?
     ORDER BY m.created_at ASC`,
    [conversationId]
  );
  return rows;
}

function ensureConversationAccess(req, res, conversation) {
  if (!conversation) {
    res.status(404).json({ error: 'Conversation not found' });
    return false;
  }

  const isCustomer = req.user.role === 'customer' && conversation.customer_id === req.user.id;
  const isOwner = req.user.role === 'businessOwner' && conversation.owner_id === req.user.id;

  if (!isCustomer && !isOwner) {
    res.status(403).json({ error: 'Access denied' });
    return false;
  }

  return true;
}

function ensureOwnerConversationAccess(req, res, conversation) {
  if (!conversation) {
    res.status(404).json({ error: 'Conversation not found' });
    return false;
  }

  if (req.user.role !== 'businessOwner' || conversation.owner_id !== req.user.id) {
    res.status(403).json({ error: 'Only the business owner can manage this conversation' });
    return false;
  }

  return true;
}

function emitChatUpdate(io, conversation, message, type = 'message') {
  if (!io || !conversation) return;

  const payload = {
    conversationId: conversation.id,
    businessId: conversation.business_id,
    customerId: conversation.customer_id,
    ownerId: conversation.owner_id,
    businessName: conversation.business_name,
    customerName: conversation.customer_name,
    type,
    isBanned: conversation.is_banned === true,
    banReason: conversation.ban_reason || null,
    bannedAt: conversation.banned_at || null,
    updatedAt: new Date().toISOString(),
    message: message
      ? {
          id: message.id,
          message: message.message,
          senderId: message.sender_id,
          senderRole: message.sender_role,
          senderName: message.sender_name,
          createdAt: message.created_at,
        }
      : null,
  };

  io.to(`chat:${conversation.id}`).emit('chat:update', payload);
  io.to(`business:${conversation.business_id}`).emit('chat:update', payload);
  io.to(`user:${conversation.customer_id}`).emit('chat:update', payload);
}

async function isUserActiveInConversation(io, userId, conversationId) {
  if (!io || !userId || !conversationId) return false;
  const sockets = await io.in(`chat:${conversationId}`).fetchSockets();
  return sockets.some((socket) => socket.data?.userId === userId);
}

router.get('/businesses/:businessId', authenticate, async (req, res) => {
  if (req.user.role !== 'customer') {
    return res.status(403).json({ error: 'Only customers can start store chats' });
  }

  try {
    const [businessRows] = await pool.query(
      'SELECT id, name, owner_id FROM businesses WHERE id = ? AND is_active = 1',
      [req.params.businessId]
    );

    if (businessRows.length === 0) {
      return res.status(404).json({ error: 'Business not found' });
    }

    const business = businessRows[0];
    const ban = await getChatBan(req.params.businessId, req.user.id);
    const [existingRows] = await pool.query(
      `SELECT c.*, b.name as business_name, u.name as customer_name, o.name as owner_name,
              cb.id as ban_id, cb.reason as ban_reason, cb.created_at as banned_at,
              CASE WHEN cb.id IS NULL THEN 0 ELSE 1 END as is_banned
       FROM business_chat_conversations c
       JOIN businesses b ON b.id = c.business_id
       JOIN users u ON u.id = c.customer_id
       JOIN users o ON o.id = c.owner_id
       LEFT JOIN business_chat_bans cb ON cb.business_id = c.business_id AND cb.customer_id = c.customer_id
       WHERE c.business_id = ? AND c.customer_id = ?`,
      [req.params.businessId, req.user.id]
    );

    let conversation = decorateConversation(existingRows[0] || null);

    if (!conversation && ban) {
      return res.json({
        conversation: {
          id: '',
          business_id: req.params.businessId,
          customer_id: req.user.id,
          owner_id: business.owner_id,
          business_name: business.name,
          is_banned: true,
          ban_reason: ban.reason || null,
          banned_at: ban.created_at,
        },
        messages: [],
        business,
      });
    }

    if (!conversation) {
      const conversationId = uuidv4();
      await pool.query(
        `INSERT INTO business_chat_conversations (id, business_id, customer_id, owner_id)
         VALUES (?,?,?,?)`,
        [conversationId, req.params.businessId, req.user.id, business.owner_id]
      );
      conversation = await getConversationById(conversationId);
    }

    const messages = conversation.id ? await getConversationMessages(conversation.id) : [];
    res.json({ conversation, messages, business });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/businesses/:businessId/conversations', authenticate, async (req, res) => {
  if (req.user.role !== 'businessOwner') {
    return res.status(403).json({ error: 'Only business owners can access inbox conversations' });
  }

  try {
    const [businessRows] = await pool.query(
      'SELECT id, name FROM businesses WHERE id = ? AND owner_id = ?',
      [req.params.businessId, req.user.id]
    );

    if (businessRows.length === 0) {
      return res.status(404).json({ error: 'Business not found' });
    }

    const [rows] = await pool.query(
      `SELECT c.*, u.name as customer_name, u.email as customer_email,
              cb.id as ban_id, cb.reason as ban_reason, cb.created_at as banned_at,
              CASE WHEN cb.id IS NULL THEN 0 ELSE 1 END as is_banned,
              m.message as last_message, m.sender_role as last_sender_role, m.created_at as last_message_created_at
       FROM business_chat_conversations c
       JOIN users u ON u.id = c.customer_id
       LEFT JOIN business_chat_bans cb ON cb.business_id = c.business_id AND cb.customer_id = c.customer_id
       LEFT JOIN business_chat_messages m ON m.id = (
         SELECT m2.id
         FROM business_chat_messages m2
         WHERE m2.conversation_id = c.id
         ORDER BY m2.created_at DESC
         LIMIT 1
       )
       WHERE c.business_id = ?
       ORDER BY COALESCE(m.created_at, c.updated_at) DESC`,
      [req.params.businessId]
    );

    res.json({
      business: businessRows[0],
      conversations: rows.map((row) => decorateConversation(row)),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/conversations/:conversationId', authenticate, async (req, res) => {
  try {
    const conversation = await getConversationById(req.params.conversationId);
    if (!ensureConversationAccess(req, res, conversation)) return;

    const messages = await getConversationMessages(conversation.id);
    res.json({ conversation, messages });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/conversations/:conversationId/messages', authenticate, async (req, res) => {
  const messageText = String(req.body.message || '').trim();
  if (!messageText) {
    return res.status(400).json({ error: 'Message required' });
  }

  try {
    const conversation = await getConversationById(req.params.conversationId);
    if (!ensureConversationAccess(req, res, conversation)) return;
    if (conversation.is_banned) {
      return res.status(403).json({ error: conversation.ban_reason || 'This conversation has been blocked by the business owner.' });
    }

    const senderRole = getSenderRole(req.user.role);
    const messageId = uuidv4();
    await pool.query(
      `INSERT INTO business_chat_messages (id, conversation_id, sender_id, sender_role, message)
       VALUES (?,?,?,?,?)`,
      [messageId, conversation.id, req.user.id, senderRole, messageText]
    );
    await pool.query(
      'UPDATE business_chat_conversations SET updated_at = NOW(), last_message_at = NOW() WHERE id = ?',
      [conversation.id]
    );

    const [messageRows] = await pool.query(
      `SELECT m.*, u.name as sender_name
       FROM business_chat_messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.id = ?`,
      [messageId]
    );

    const recipientId = req.user.role === 'businessOwner' ? conversation.customer_id : conversation.owner_id;
    const io = req.app.get('io');
    const recipientActiveInConversation = await isUserActiveInConversation(io, recipientId, conversation.id);
    if (!recipientActiveInConversation) {
      await createNotification({
        pool,
        io,
        userId: recipientId,
        title: req.user.role === 'businessOwner' ? 'New message from the business' : 'New customer message',
        body: messageText,
        type: 'chat_message',
        entityType: 'conversation',
        entityId: conversation.id,
        metadata: {
          conversationId: conversation.id,
          businessId: conversation.business_id,
          businessName: conversation.business_name,
          customerName: conversation.customer_name,
          senderRole,
        },
      });
    }

    emitChatUpdate(io, conversation, messageRows[0], 'message');

    res.status(201).json({
      success: true,
      message: messageRows[0],
      conversationId: conversation.id,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/conversations/:conversationId/ban', authenticate, async (req, res) => {
  if (req.user.role !== 'businessOwner') {
    return res.status(403).json({ error: 'Only business owners can ban chat users' });
  }

  try {
    const conversation = await getConversationById(req.params.conversationId);
    if (!ensureOwnerConversationAccess(req, res, conversation)) return;

    const reason = String(req.body.reason || '').trim();
    await pool.query(
      `INSERT INTO business_chat_bans (id, business_id, customer_id, owner_id, reason)
       VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE owner_id = VALUES(owner_id), reason = VALUES(reason), created_at = CURRENT_TIMESTAMP`,
      [uuidv4(), conversation.business_id, conversation.customer_id, req.user.id, reason || null]
    );

    const refreshedConversation = await getConversationById(req.params.conversationId);
    emitChatUpdate(req.app.get('io'), refreshedConversation, null, 'ban');
    res.json({ success: true, conversation: refreshedConversation });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/conversations/:conversationId/ban', authenticate, async (req, res) => {
  if (req.user.role !== 'businessOwner') {
    return res.status(403).json({ error: 'Only business owners can unban chat users' });
  }

  try {
    const conversation = await getConversationById(req.params.conversationId);
    if (!ensureOwnerConversationAccess(req, res, conversation)) return;

    await pool.query(
      'DELETE FROM business_chat_bans WHERE business_id = ? AND customer_id = ?',
      [conversation.business_id, conversation.customer_id]
    );

    const refreshedConversation = await getConversationById(req.params.conversationId);
    emitChatUpdate(req.app.get('io'), refreshedConversation, null, 'unban');
    res.json({ success: true, conversation: refreshedConversation });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;