const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

async function emitProductUpdate(req, businessId, productId = null, action = 'updated') {
  const io = req.app.get('io');
  if (!io || !businessId) return;

  let product = null;
  if (productId) {
    const [rows] = await pool.query('SELECT * FROM products WHERE id = ?', [productId]);
    product = rows[0] || null;
  }

  io.to(`business:${businessId}`).emit('product:update', {
    businessId,
    productId,
    action,
    product,
    updatedAt: new Date().toISOString(),
  });
}

// GET /api/products?businessId=xxx
router.get('/', async (req, res) => {
  try {
    const { businessId } = req.query;
    if (!businessId) return res.status(400).json({ error: 'businessId required' });
    const [rows] = await pool.query('SELECT * FROM products WHERE business_id = ? ORDER BY name ASC', [businessId]);
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/products (owner only)
router.post('/', authenticate, async (req, res) => {
  const { business_id, name, description, price, stock, image_url, duration_minutes, cost } = req.body;
  if (!business_id || !name) return res.status(400).json({ error: 'business_id and name required' });

  try {
    // Verify ownership
    const [biz] = await pool.query('SELECT id FROM businesses WHERE id = ? AND owner_id = ?', [business_id, req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    const id = uuidv4();
    await pool.query(
      'INSERT INTO products (id, business_id, name, description, price, stock, image_url, duration_minutes, cost) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, business_id, name, description || '', price || 0, stock || 0, image_url || null, duration_minutes != null ? duration_minutes : 60, cost || 0]
    );
    const [row] = await pool.query('SELECT * FROM products WHERE id = ?', [id]);
    await emitProductUpdate(req, business_id, id, 'created');
    res.status(201).json(row[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/products/:id
router.put('/:id', authenticate, async (req, res) => {
  const { name, description, price, stock, is_available, is_off_sale, image_url, duration_minutes, cost } = req.body;
  // Protect against NULL — default to visible and not-off-sale
  const safeIsAvailable = is_available != null ? (is_available ? 1 : 0) : 1;
  const safeIsOffSale = is_off_sale != null ? (is_off_sale ? 1 : 0) : 0;
  try {
    await pool.query(
      `UPDATE products p
       JOIN businesses b ON p.business_id = b.id
       SET p.name=?, p.description=?, p.price=?, p.stock=?, p.is_available=?, p.is_off_sale=?, p.image_url=COALESCE(?, p.image_url), p.duration_minutes=COALESCE(?, p.duration_minutes), p.cost=COALESCE(?, p.cost)
       WHERE p.id=? AND b.owner_id=?`,
      [name, description, price, stock, safeIsAvailable, safeIsOffSale, image_url ?? null, duration_minutes ?? null, cost ?? null, req.params.id, req.user.id]
    );
    const [row] = await pool.query('SELECT * FROM products WHERE id = ?', [req.params.id]);
    if (row[0]?.business_id) {
      await emitProductUpdate(req, row[0].business_id, req.params.id, 'updated');
    }
    res.json(row[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// DELETE /api/products/:id
router.delete('/:id', authenticate, async (req, res) => {
  try {
    const [productRows] = await pool.query('SELECT id, business_id FROM products WHERE id = ?', [req.params.id]);
    await pool.query(
      `DELETE p FROM products p JOIN businesses b ON p.business_id = b.id WHERE p.id = ? AND b.owner_id = ?`,
      [req.params.id, req.user.id]
    );
    if (productRows[0]?.business_id) {
      await emitProductUpdate(req, productRows[0].business_id, req.params.id, 'deleted');
    }
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
