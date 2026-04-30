const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate, authorizeOwner } = require('../middleware/auth');
const { emitBusinessUpdate } = require('../utils/business_updates');

const router = express.Router();

const BUSINESS_CATEGORIES = new Set(['bakery', 'barber', 'restaurant', 'clinic', 'bank', 'repair', 'beauty', 'dentist', 'gym', 'pharmacy', 'grocery', 'government', 'cafe', 'vet', 'other']);
const SERVICE_TYPES = new Set(['queue', 'appointment', 'both']);

function parseCoordinate(value, min, max, label) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    const error = new Error(`${label} must be between ${min} and ${max}.`);
    error.status = 400;
    throw error;
  }

  return parsed;
}

// GET /api/businesses/owner/:ownerId (MUST come before /:id route)
router.get('/owner/:ownerId', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM businesses WHERE owner_id = ?', [req.params.ownerId]);
    res.json(rows[0] || null);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/businesses
router.get('/', async (req, res) => {
  try {
    const { category, search } = req.query;
    let sql = `SELECT
                 b.*,
                 COALESCE(q.waiting_count, 0) as waiting_count,
                 COALESCE(q.serving_count, 0) as serving_count,
                 COALESCE(
                   (
                     SELECT ROUND(AVG(qe.service_duration_seconds))
                     FROM queue_entries qe
                     WHERE qe.business_id = b.id
                       AND qe.status = 'done'
                       AND qe.service_duration_seconds IS NOT NULL
                       AND qe.completed_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
                   ),
                   (
                     SELECT ROUND(AVG(qe.product_duration_minutes) * 60)
                     FROM queue_entries qe
                     WHERE qe.business_id = b.id
                       AND qe.status IN ('waiting','serving')
                       AND qe.product_duration_minutes > 0
                   ),
                   300
                 ) as avg_service_seconds
               FROM businesses b
               LEFT JOIN queues q ON q.business_id = b.id
               WHERE b.is_active = 1 AND b.approval_status = 'approved'`;
    const params = [];

    if (category) { sql += ' AND b.category = ?'; params.push(category); }
    if (search)   { sql += ' AND (b.name LIKE ? OR b.description LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }

    sql += ' ORDER BY b.name ASC';
    const [rows] = await pool.query(sql, params);
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/businesses/:id
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT * FROM businesses WHERE id = ? AND is_active = 1 AND approval_status = 'approved'", [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Business not found' });
    res.json(rows[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/businesses/:id (owner only)
router.put('/:id', authenticate, async (req, res) => {
  try {
    const [existingRows] = await pool.query('SELECT * FROM businesses WHERE id = ? AND owner_id = ?', [req.params.id, req.user.id]);
    if (existingRows.length === 0) return res.status(404).json({ error: 'Business not found' });

    const existing = existingRows[0];
    const incoming = req.body || {};
    const hasOwn = (key) => Object.prototype.hasOwnProperty.call(incoming, key);
    const nextName = hasOwn('name') ? String(incoming.name || '').trim() : existing.name;

    if (!nextName) {
      return res.status(400).json({ error: 'Business name is required' });
    }

    const nextCategory = BUSINESS_CATEGORIES.has(incoming.category) ? incoming.category : existing.category;
    const nextServiceType = SERVICE_TYPES.has(incoming.service_type) ? incoming.service_type : existing.service_type;
    const nextLatitude = hasOwn('latitude') ? parseCoordinate(incoming.latitude, -90, 90, 'Latitude') : existing.latitude;
    const nextLongitude = hasOwn('longitude') ? parseCoordinate(incoming.longitude, -180, 180, 'Longitude') : existing.longitude;

    await pool.query(
      'UPDATE businesses SET name=?, description=?, address=?, phone=?, image_url=?, latitude=?, longitude=?, is_active=?, category=?, service_type=? WHERE id=? AND owner_id=?',
      [
        nextName,
        hasOwn('description') ? (incoming.description ?? '') : existing.description,
        hasOwn('address') ? (incoming.address ?? '') : existing.address,
        hasOwn('phone') ? (incoming.phone ?? '') : existing.phone,
        hasOwn('image_url') ? (incoming.image_url || null) : existing.image_url,
        nextLatitude,
        nextLongitude,
        hasOwn('is_active') ? (incoming.is_active ? 1 : 0) : existing.is_active,
        nextCategory,
        nextServiceType,
        req.params.id,
        req.user.id,
      ]
    );
    const [rows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [req.params.id]);
    await emitBusinessUpdate({ io: req.app.get('io'), business: rows[0] });
    res.json(rows[0]);
  } catch (err) { res.status(err.status || 500).json({ error: err.message }); }
});

// POST /api/businesses/:id/rating
router.post('/:id/rating', authenticate, async (req, res) => {
  const { rating, comment, products_purchased, entry_id, entry_type } = req.body;
  if (!rating || rating < 1 || rating > 5) return res.status(400).json({ error: 'Rating must be between 1 and 5' });
  if (!entry_id) return res.status(400).json({ error: 'entry_id is required' });

  try {
    // Upsert rating keyed by entry_id (one rating per order)
    await pool.query(
      `INSERT INTO ratings (id, business_id, customer_id, entry_id, entry_type, rating, comment, products_purchased)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE rating = ?, comment = COALESCE(?, comment), products_purchased = COALESCE(?, products_purchased)`,
      [
        uuidv4(), req.params.id, req.user.id, entry_id, entry_type || null, rating, comment || null, products_purchased || null,
        rating, comment || null, products_purchased || null,
      ]
    );

    // Recalculate average for the business
    const [stats] = await pool.query('SELECT COUNT(*) as count, AVG(rating) as avg FROM ratings WHERE business_id = ?', [req.params.id]);
    await pool.query('UPDATE businesses SET rating = ?, rating_count = ? WHERE id = ?', [stats[0].avg, stats[0].count, req.params.id]);

    res.json({ rating: stats[0].avg, count: stats[0].count });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/businesses/:id/reviews?page=1&limit=5
router.get('/:id/reviews', async (req, res) => {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(20, Math.max(1, parseInt(req.query.limit) || 5));
  const offset = (page - 1) * limit;

  try {
    const [countRows] = await pool.query('SELECT COUNT(*) as total FROM ratings WHERE business_id = ?', [req.params.id]);
    const total = countRows[0].total;

    const [rows] = await pool.query(
      `SELECT r.id, r.rating, r.comment, r.products_purchased, r.created_at, u.name as customer_name,
              rr.reply_text, COALESCE(rr.updated_at, rr.created_at) as reply_date
       FROM ratings r
       JOIN users u ON r.customer_id = u.id
       LEFT JOIN review_replies rr ON rr.rating_id = r.id
       WHERE r.business_id = ?
       ORDER BY r.created_at DESC
       LIMIT ? OFFSET ?`,
      [req.params.id, limit, offset]
    );

    res.json({
      reviews: rows,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/businesses/:id/reviews/:reviewId/reply — owner replies to a review
router.post('/:id/reviews/:reviewId/reply', authenticate, async (req, res) => {
  const { reply_text } = req.body;
  if (!reply_text || !reply_text.trim()) return res.status(400).json({ error: 'Reply text is required' });

  try {
    // Verify ownership
    const [biz] = await pool.query('SELECT id FROM businesses WHERE id = ? AND owner_id = ?', [req.params.id, req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Not your business' });

    // Verify review belongs to this business
    const [review] = await pool.query('SELECT id FROM ratings WHERE id = ? AND business_id = ?', [req.params.reviewId, req.params.id]);
    if (review.length === 0) return res.status(404).json({ error: 'Review not found' });

    // Upsert reply
    const replyId = uuidv4();
    await pool.query(
      `INSERT INTO review_replies (id, rating_id, business_id, reply_text)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE reply_text = ?, updated_at = NOW()`,
      [replyId, req.params.reviewId, req.params.id, reply_text.trim(), reply_text.trim()]
    );

    res.json({ success: true, reply_id: replyId });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/businesses/:id/has-purchased — check if current user has a completed order
router.get('/:id/has-purchased', authenticate, async (req, res) => {
  try {
    const [queueRows] = await pool.query(
      "SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND customer_id = ? AND status = 'done'",
      [req.params.id, req.user.id]
    );
    const [apptRows] = await pool.query(
      "SELECT COUNT(*) as cnt FROM appointments WHERE business_id = ? AND customer_id = ? AND status = 'completed'",
      [req.params.id, req.user.id]
    );
    const hasPurchased = (queueRows[0].cnt > 0) || (apptRows[0].cnt > 0);
    res.json({ hasPurchased });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
