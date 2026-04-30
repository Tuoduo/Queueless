const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

function serializeDiscount(discount) {
  return {
    ...discount,
    value: parseFloat(discount.value || 0) || 0,
    max_usage_count: parseInt(discount.max_usage_count?.toString() || '0', 10) || 0,
    used_count: parseInt(discount.used_count?.toString() || '0', 10) || 0,
    is_active: discount.is_active === 1 || discount.is_active === true,
  };
}

// GET /api/discounts?businessId=xxx  (public — for applying codes)
router.get('/', async (req, res) => {
  const { businessId } = req.query;
  if (!businessId) return res.status(400).json({ error: 'businessId required' });

  try {
    const [rows] = await pool.query(
      'SELECT * FROM discounts WHERE business_id = ? AND is_active = 1 AND used_count < max_usage_count AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY created_at DESC',
      [businessId]
    );
    res.json(rows.map(serializeDiscount));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/discounts/validate — validate a coupon code
router.post('/validate', async (req, res) => {
  const { businessId, code, amount } = req.body;
  if (!businessId || !code) return res.status(400).json({ error: 'businessId and code required' });

  try {
    const [rows] = await pool.query(
      'SELECT * FROM discounts WHERE business_id = ? AND code = ? AND is_active = 1 AND used_count < max_usage_count AND (expires_at IS NULL OR expires_at > NOW())',
      [businessId, code.toUpperCase()]
    );

    if (rows.length === 0) return res.status(404).json({ error: 'Invalid or expired coupon code' });

    const discount = rows[0];
    const baseAmount = parseFloat(amount || 0);
    const discountValue = parseFloat(discount.value || 0) || 0;
    const discountAmount = discount.type === 'percentage'
      ? parseFloat((baseAmount * discountValue / 100).toFixed(2))
      : Math.min(discountValue, baseAmount);
    const finalAmount = parseFloat(Math.max(0, baseAmount - discountAmount).toFixed(2));

    res.json({
      valid: true,
      discount: serializeDiscount(discount),
      discount_amount: discountAmount,
      final_amount: finalAmount,
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/discounts/mine — owner's own coupons
router.get('/mine', authenticate, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE owner_id = ?', [req.user.id]);
    if (biz.length === 0) return res.json([]);

    const [rows] = await pool.query(
      'SELECT * FROM discounts WHERE business_id = ? ORDER BY created_at DESC',
      [biz[0].id]
    );
    res.json(rows.map(serializeDiscount));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/discounts — create coupon (owner)
router.post('/', authenticate, async (req, res) => {
  const { code, type, value, max_usage_count, expires_at } = req.body;
  if (!code || !type || !value) return res.status(400).json({ error: 'code, type and value required' });
  if (!['percentage', 'fixed'].includes(type)) return res.status(400).json({ error: "type must be 'percentage' or 'fixed'" });

  // Normalize expires_at to MySQL-compatible format (same fix as appointments datetime)
  let formattedExpiresAt = null;
  if (expires_at) {
    try {
      formattedExpiresAt = new Date(expires_at).toISOString().replace('T', ' ').slice(0, 19);
    } catch {
      return res.status(400).json({ error: 'Invalid expires_at date format' });
    }
  }

  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE owner_id = ?', [req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'No business found for this owner' });

    const id = uuidv4();
    await pool.query(
      'INSERT INTO discounts (id, business_id, code, type, value, max_usage_count, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, biz[0].id, code.toUpperCase(), type, parseFloat(value), parseInt(max_usage_count || 1), formattedExpiresAt]
    );

    const [row] = await pool.query('SELECT * FROM discounts WHERE id = ?', [id]);
    res.status(201).json(serializeDiscount(row[0]));
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Coupon code already exists for this business' });
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/discounts/:id/toggle — activate/deactivate
router.put('/:id/toggle', authenticate, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE owner_id = ?', [req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    await pool.query(
      'UPDATE discounts SET is_active = IF(is_active = 1, 0, 1) WHERE id = ? AND business_id = ?',
      [req.params.id, biz[0].id]
    );
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// DELETE /api/discounts/:id
router.delete('/:id', authenticate, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE owner_id = ?', [req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    await pool.query('DELETE FROM discounts WHERE id = ? AND business_id = ?', [req.params.id, biz[0].id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
