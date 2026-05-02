const express = require('express');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { mapNotificationRow } = require('../utils/notifications');

const router = express.Router();

router.get('/', authenticate, async (req, res) => {
  try {
    const limit = Math.min(200, Math.max(1, parseInt(req.query.limit?.toString() || '100', 10) || 100));
    const [rows] = await pool.query(
      'SELECT * FROM notifications WHERE recipient_id = ? ORDER BY is_read ASC, created_at DESC LIMIT ?',
      [req.user.id, limit]
    );
    const [[{ unread_count: unreadCount }]] = await pool.query(
      'SELECT COUNT(*) as unread_count FROM notifications WHERE recipient_id = ? AND is_read = 0',
      [req.user.id]
    );
    res.json({ notifications: rows.map(mapNotificationRow), unreadCount: parseInt(unreadCount, 10) || 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id/read', authenticate, async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET is_read = 1 WHERE id = ? AND recipient_id = ?', [req.params.id, req.user.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/read-all', authenticate, async (req, res) => {
  try {
    await pool.query('UPDATE notifications SET is_read = 1 WHERE recipient_id = ?', [req.user.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/clear-all', authenticate, async (req, res) => {
  try {
    await pool.query('DELETE FROM notifications WHERE recipient_id = ?', [req.user.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', authenticate, async (req, res) => {
  try {
    await pool.query('DELETE FROM notifications WHERE id = ? AND recipient_id = ?', [req.params.id, req.user.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;