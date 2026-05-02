const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { createNotification, createNotifications } = require('../utils/notifications');
const { emitBusinessUpdate } = require('../utils/business_updates');
const { buildEtaConfig, estimateQueueWaitRange, formatEtaRangeLabel } = require('../utils/eta');

const router = express.Router();

async function getAverageQueueSeconds(businessId) {
  const [rows] = await pool.query(
    `SELECT COALESCE(
        (SELECT ROUND(AVG(product_duration_minutes) * 60)
         FROM queue_entries
         WHERE business_id = ? AND status IN ('waiting', 'serving') AND product_duration_minutes > 0),
        (SELECT ROUND(AVG(service_duration_seconds))
         FROM queue_entries
         WHERE business_id = ? AND status = 'done' AND service_duration_seconds IS NOT NULL
         AND completed_at > DATE_SUB(NOW(), INTERVAL 7 DAY)),
        300
      ) AS avg_sec`,
    [businessId, businessId]
  );
  return rows[0]?.avg_sec ? Math.round(rows[0].avg_sec) : 300;
}

function createHttpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function normalizeQueueItems(items) {
  if (!Array.isArray(items)) return [];

  return items.reduce((result, item) => {
    const productId = item?.productId?.toString().trim();
    if (!productId) return result;

    const quantity = Math.max(1, parseInt(item.quantity?.toString() || '1', 10) || 1);
    result.push({ productId, quantity });
    return result;
  }, []);
}

async function buildQueueCheckout(businessId, items) {
  const normalizedItems = normalizeQueueItems(items);
  if (normalizedItems.length === 0) {
    return {
      normalizedItems: [],
      productSummary: null,
      totalItemCount: 1,
      totalDurationMinutes: 0,
      baseTotalPrice: 0,
    };
  }

  const uniqueProductIds = [...new Set(normalizedItems.map((item) => item.productId))];
  const placeholders = uniqueProductIds.map(() => '?').join(',');
  const [productRows] = await pool.query(
    `SELECT id, name, price, cost, duration_minutes, stock, is_available, is_off_sale
     FROM products
     WHERE business_id = ? AND id IN (${placeholders})`,
    [businessId, ...uniqueProductIds]
  );

  const productsById = new Map(productRows.map((row) => [row.id, row]));
  if (productsById.size !== uniqueProductIds.length) {
    throw createHttpError(400, 'One or more selected products could not be found.');
  }

  let totalDurationMinutes = 0;
  let totalItemCount = 0;
  let baseTotalPrice = 0;
  let baseTotalCost = 0;
  const summaryParts = [];

  for (const item of normalizedItems) {
    const product = productsById.get(item.productId);
    if (!product) {
      throw createHttpError(400, 'One or more selected products could not be found.');
    }

    const isAvailable = product.is_available === 1 || product.is_available === true;
    const isOffSale = product.is_off_sale === 1 || product.is_off_sale === true;
    const stock = parseInt(product.stock?.toString() || '0', 10) || 0;
    const price = parseFloat(product.price || 0) || 0;
    const durationMinutes = parseInt(product.duration_minutes?.toString() || '0', 10) || 0;
    // stock===0 means unlimited (services have no stock limit); only block when stock was set > 0 and ran out
    const isStockDepleted = stock < 0;
    if (!isAvailable || isOffSale || isStockDepleted) {
      throw createHttpError(400, `${product.name} is currently unavailable.`);
    }

    const cost = parseFloat(product.cost || 0) || 0;
    totalItemCount += item.quantity;
    totalDurationMinutes += durationMinutes * item.quantity;
    baseTotalPrice += price * item.quantity;
    baseTotalCost += cost * item.quantity;
    summaryParts.push(`${item.quantity}x ${product.name}`);
  }

  return {
    normalizedItems,
    productSummary: summaryParts.join(', '),
    totalItemCount: Math.max(1, totalItemCount),
    totalDurationMinutes,
    baseTotalPrice: parseFloat(baseTotalPrice.toFixed(2)),
    baseTotalCost: parseFloat(baseTotalCost.toFixed(2)),
  };
}

async function getBusinessOwnerId(businessId) {
  const [rows] = await pool.query('SELECT owner_id, name FROM businesses WHERE id = ?', [businessId]);
  return rows[0] || null;
}

async function getActiveCustomerIdsForBusiness(businessId) {
  const [rows] = await pool.query(
    "SELECT DISTINCT customer_id FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') AND customer_id IS NOT NULL",
    [businessId]
  );
  return rows.map((row) => row.customer_id).filter(Boolean);
}

async function applyQueueDiscount(businessId, discountCode, baseTotalPrice) {
  const normalizedCode = discountCode?.toString().trim().toUpperCase();
  if (!normalizedCode) {
    return {
      appliedDiscountCode: null,
      appliedDiscountAmount: 0,
      finalTotalPrice: baseTotalPrice,
    };
  }

  if (baseTotalPrice <= 0) {
    throw createHttpError(400, 'Add a product before applying a coupon.');
  }

  const [discountRows] = await pool.query(
    'SELECT * FROM discounts WHERE business_id = ? AND code = ? AND is_active = 1 AND used_count < max_usage_count AND (expires_at IS NULL OR expires_at > NOW())',
    [businessId, normalizedCode]
  );

  if (discountRows.length === 0) {
    throw createHttpError(400, 'Invalid or expired coupon code');
  }

  const discount = discountRows[0];
  const discountValue = parseFloat(discount.value || 0) || 0;
  const appliedDiscountAmount = discount.type === 'percentage'
    ? parseFloat((baseTotalPrice * discountValue / 100).toFixed(2))
    : Math.min(discountValue, baseTotalPrice);
  const finalTotalPrice = parseFloat(Math.max(0, baseTotalPrice - appliedDiscountAmount).toFixed(2));

  await pool.query('UPDATE discounts SET used_count = used_count + 1 WHERE id = ?', [discount.id]);

  return {
    appliedDiscountCode: normalizedCode,
    appliedDiscountAmount,
    finalTotalPrice,
  };
}

// Helper: get queue snapshot with avg service time, then broadcast via socket.io
async function broadcastQueueUpdate(req, businessId) {
  try {
    const io = req.app.get('io');
    if (!io) return;

    const [queueRows] = await pool.query('SELECT * FROM queues WHERE business_id = ?', [businessId]);
    const [entries] = await pool.query(
      "SELECT * FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') ORDER BY position ASC",
      [businessId]
    );
    const avgServiceSec = await getAverageQueueSeconds(businessId);

    const payload = {
      queue: queueRows[0] || null,
      entries,
      avgServiceSeconds: avgServiceSec,
    };
    io.to(`business:${businessId}`).emit('queue:update', payload);

    const [businessRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [businessId]);
    if (businessRows[0]) {
      await emitBusinessUpdate({ io, business: businessRows[0] });
    }
  } catch (e) {
    console.error('broadcastQueueUpdate error:', e.message);
  }
}

function emitHistoryUpdate(req, userId, payload = {}) {
  const io = req.app.get('io');
  if (!io || !userId) return;
  io.to(`user:${userId}`).emit('history:update', payload);
}

// GET /api/queues/:businessId
router.get('/:businessId', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM queues WHERE business_id = ?', [req.params.businessId]);
    const avgServiceSec = await getAverageQueueSeconds(req.params.businessId);
    const queue = rows[0] || {
      id: '',
      business_id: req.params.businessId,
      waiting_count: 0,
      serving_count: 0,
      is_open: 1,
      is_paused: 0,
      paused_at: null,
    };
    res.json({ ...queue, avg_service_seconds: avgServiceSec });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/queues/:businessId/entries — all entries for business owner
router.get('/:businessId/entries', authenticate, async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') ORDER BY position ASC",
      [req.params.businessId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/queues/:businessId/completed — all delivered orders for business owner
router.get('/:businessId/completed', authenticate, async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM queue_entries WHERE business_id = ? AND status = 'done' ORDER BY COALESCE(completed_at, joined_at) DESC LIMIT 200",
      [req.params.businessId]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
})

// GET /api/queues/user/me — customer's active queues
router.get('/user/me', authenticate, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT qe.*, b.name as business_name, b.address, b.category, b.latitude, b.longitude
       FROM queue_entries qe
       JOIN businesses b ON qe.business_id = b.id
       WHERE qe.customer_id = ? AND qe.status IN ('waiting','serving')`,
      [req.user.id]
    );

    const avgSecondsByBusiness = new Map();
    const enrichedRows = [];

    for (const row of rows) {
      let avgServiceSeconds = avgSecondsByBusiness.get(row.business_id);
      if (avgServiceSeconds == null) {
        avgServiceSeconds = await getAverageQueueSeconds(row.business_id);
        avgSecondsByBusiness.set(row.business_id, avgServiceSeconds);
      }

      const [aheadRows] = await pool.query(
        `SELECT item_count, product_duration_minutes
         FROM queue_entries
         WHERE business_id = ? AND status = 'waiting' AND position < ?
         ORDER BY position ASC`,
        [row.business_id, row.position]
      );

      const etaConfig = buildEtaConfig(avgServiceSeconds);
      const waitRange = estimateQueueWaitRange(aheadRows, etaConfig);

      enrichedRows.push({
        ...row,
        people_ahead: aheadRows.length,
        avg_service_seconds: avgServiceSeconds,
        estimated_wait_seconds: Math.round(((waitRange.minMinutes + waitRange.maxMinutes) / 2) * 60),
        estimated_wait_min_minutes: waitRange.minMinutes,
        estimated_wait_max_minutes: waitRange.maxMinutes,
        estimated_wait_label: formatEtaRangeLabel(waitRange.minMinutes, waitRange.maxMinutes),
      });
    }

    res.json(enrichedRows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/queues/:businessId/join
router.post('/:businessId/join', authenticate, async (req, res) => {
  const { productName, items, discountCode, paymentMethod } = req.body;
  try {
    const [queueRow] = await pool.query('SELECT is_paused FROM queues WHERE business_id = ?', [req.params.businessId]);
    if (queueRow[0] && queueRow[0].is_paused) {
      return res.status(403).json({ error: 'Queue is temporarily paused. Please try again after it resumes.' });
    }

    const [existing] = await pool.query(
      "SELECT id FROM queue_entries WHERE business_id = ? AND customer_id = ? AND status IN ('waiting','serving')",
      [req.params.businessId, req.user.id]
    );
    if (existing.length > 0) return res.status(409).json({ error: 'You are already in this queue.' });

    const [pos] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [req.params.businessId]);
    const position = (pos[0].cnt || 0) + 1;

    const entryId = uuidv4();
    const [userRow] = await pool.query('SELECT name FROM users WHERE id = ?', [req.user.id]);

    const checkout = await buildQueueCheckout(req.params.businessId, items);
    const discount = await applyQueueDiscount(req.params.businessId, discountCode, checkout.baseTotalPrice);
    const queueNote = checkout.productSummary || (typeof productName === 'string' && productName.trim() ? productName.trim() : null);
    const normalizedPaymentMethod = paymentMethod === 'now' ? 'now' : 'later';

    await pool.query(
      'INSERT INTO queue_entries (id, business_id, customer_id, customer_name, product_name, item_count, position, status, product_duration_minutes, total_price, total_cost, payment_method, discount_code, discount_amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        entryId,
        req.params.businessId,
        req.user.id,
        userRow[0]?.name || 'Customer',
        queueNote,
        checkout.totalItemCount,
        position,
        'waiting',
        checkout.totalDurationMinutes,
        discount.finalTotalPrice,
        checkout.baseTotalCost,
        normalizedPaymentMethod,
        discount.appliedDiscountCode,
        discount.appliedDiscountAmount,
      ]
    );

    await pool.query(
      'INSERT INTO queues (id, business_id, waiting_count) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE waiting_count = waiting_count + 1',
      [uuidv4(), req.params.businessId]
    );

    // Decrement stock for each purchased item (only when stock > 0, i.e. tracked inventory)
    for (const item of checkout.normalizedItems) {
      await pool.query(
        'UPDATE products SET stock = GREATEST(stock - ?, 0) WHERE id = ? AND stock > 0',
        [item.quantity, item.productId]
      );
    }

    const [entry] = await pool.query('SELECT * FROM queue_entries WHERE id = ?', [entryId]);
    const business = await getBusinessOwnerId(req.params.businessId);
    if (business?.owner_id) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: business.owner_id,
        title: 'New order in queue',
        body: `${userRow[0]?.name || 'A customer'} joined ${business.name || 'your business'}${queueNote ? ` with ${queueNote}.` : '.'}`,
        type: 'queue_joined',
        entityType: 'queue_entry',
        entityId: entryId,
        metadata: { businessId: req.params.businessId, customerId: req.user.id, paymentMethod: normalizedPaymentMethod },
      });
    }
    await broadcastQueueUpdate(req, req.params.businessId);
    res.status(201).json(entry[0]);
  } catch (err) { res.status(err.status || 500).json({ error: err.message }); }
});

// PUT /api/queues/entries/:entryId/status
router.put('/entries/:entryId/status', authenticate, async (req, res) => {
  const { status } = req.body;
  try {
    const [entry] = await pool.query('SELECT business_id, customer_id, customer_name, product_name, status as old_status, started_at FROM queue_entries WHERE id = ?', [req.params.entryId]);
    if (entry.length === 0) return res.status(404).json({ error: 'Entry not found' });

    const businessId = entry[0].business_id;
    const customerId = entry[0].customer_id;
    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

    if (status === 'serving') {
      await pool.query('UPDATE queue_entries SET status = ?, started_at = ? WHERE id = ?', [status, now, req.params.entryId]);
    } else if (status === 'done') {
      const startedAt = entry[0].started_at;
      let durationSec = null;
      if (startedAt) {
        durationSec = Math.round((Date.now() - new Date(startedAt).getTime()) / 1000);
      }
      // Use MySQL NOW() to avoid timezone mismatch between Node.js (UTC) and MySQL server
      await pool.query(
        'UPDATE queue_entries SET status = ?, completed_at = NOW(), service_duration_seconds = ? WHERE id = ?',
        [status, durationSec, req.params.entryId]
      );
      // Update total customers served
      await pool.query('UPDATE businesses SET total_customers_served = total_customers_served + 1 WHERE id = ?', [businessId]);
    } else {
      await pool.query('UPDATE queue_entries SET status = ? WHERE id = ?', [status, req.params.entryId]);
    }

    // Recalculate queue stats
    const [waiting] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [businessId]);
    const [serving] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'serving'", [businessId]);
    await pool.query('UPDATE queues SET waiting_count = ?, serving_count = ? WHERE business_id = ?', [waiting[0].cnt, serving[0].cnt, businessId]);

    await broadcastQueueUpdate(req, businessId);
    const business = await getBusinessOwnerId(businessId);
    if (status === 'serving' && customerId) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: customerId,
        title: 'Your order is being served',
        body: `${business?.name || 'Your business'} started serving ${entry[0].product_name || 'your order'}.`,
        type: 'queue_serving',
        entityType: 'queue_entry',
        entityId: req.params.entryId,
        metadata: { businessId },
      });
    }
    if (status === 'done') {
      if (customerId) {
        await createNotification({
          pool,
          io: req.app.get('io'),
          userId: customerId,
          title: 'Your order is ready',
          body: `${business?.name || 'The business'} marked ${entry[0].product_name || 'your order'} as ready.`,
          type: 'queue_done',
          entityType: 'queue_entry',
          entityId: req.params.entryId,
          metadata: { businessId },
        });
      }
      emitHistoryUpdate(req, customerId, {
        type: 'queue',
        entryId: req.params.entryId,
        businessId,
      });
    }
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// DELETE /api/queues/entries/:entryId (leave queue)
router.delete('/entries/:entryId', authenticate, async (req, res) => {
  try {
    const [entry] = await pool.query('SELECT business_id FROM queue_entries WHERE id = ? AND customer_id = ?', [req.params.entryId, req.user.id]);
    if (entry.length === 0) return res.status(404).json({ error: 'Entry not found' });

    await pool.query('UPDATE queue_entries SET status = ? WHERE id = ?', ['cancelled', req.params.entryId]);

    const businessId = entry[0].business_id;
    const [waiting] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [businessId]);
    await pool.query('UPDATE queues SET waiting_count = ? WHERE business_id = ?', [waiting[0].cnt, businessId]);

    await broadcastQueueUpdate(req, businessId);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/:businessId/reorder', authenticate, async (req, res) => {
  const orderedEntryIds = Array.isArray(req.body?.orderedEntryIds) ? req.body.orderedEntryIds : [];
  if (orderedEntryIds.length == 0) return res.status(400).json({ error: 'orderedEntryIds required' });

  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE id = ? AND owner_id = ?', [req.params.businessId, req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    const [activeRows] = await pool.query(
      "SELECT id, status FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') ORDER BY position ASC",
      [req.params.businessId]
    );
    if (activeRows.length === 0) return res.status(404).json({ error: 'No active queue entries found' });

    const waitingRows = activeRows.filter((row) => row.status === 'waiting');
    const servingRows = activeRows.filter((row) => row.status === 'serving');
    if (waitingRows.length !== orderedEntryIds.length) {
      return res.status(400).json({ error: 'orderedEntryIds must include all waiting entries' });
    }

    const waitingIds = waitingRows.map((row) => row.id).sort();
    const incomingIds = orderedEntryIds.map((id) => id.toString()).sort();
    if (waitingIds.join(',') !== incomingIds.join(',')) {
      return res.status(400).json({ error: 'orderedEntryIds do not match current waiting entries' });
    }

    const finalOrder = [...servingRows.map((row) => row.id), ...orderedEntryIds.map((id) => id.toString())];
    for (let index = 0; index < finalOrder.length; index += 1) {
      await pool.query('UPDATE queue_entries SET position = ? WHERE id = ?', [index + 1, finalOrder[index]]);
    }

    await broadcastQueueUpdate(req, req.params.businessId);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});



// POST /api/queues/:businessId/join-guest — join queue without authentication (QR scan)
router.post('/:businessId/join-guest', async (req, res) => {
  const { guest_name, product_name, items, discountCode, payment_method } = req.body;
  if (!guest_name || !guest_name.trim()) return res.status(400).json({ error: 'guest_name required' });
  try {
    const [biz] = await pool.query('SELECT id, name, service_type, is_active FROM businesses WHERE id = ?', [req.params.businessId]);
    if (biz.length === 0) return res.status(404).json({ error: 'Business not found' });
    if (!biz[0].is_active) return res.status(403).json({ error: 'Business is currently closed' });
    if (!['queue', 'both'].includes(biz[0].service_type)) return res.status(403).json({ error: 'This business does not use queue service' });

    const [queueRow] = await pool.query('SELECT is_paused FROM queues WHERE business_id = ?', [req.params.businessId]);
    if (queueRow[0] && queueRow[0].is_paused) return res.status(403).json({ error: 'Queue is temporarily paused. Please try again after it resumes.' });

    const [pos] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [req.params.businessId]);
    const position = (pos[0].cnt || 0) + 1;
    const entryId = uuidv4();
    const guestCustomerId = uuidv4();

    const checkout = await buildQueueCheckout(req.params.businessId, items);
    const discount = await applyQueueDiscount(req.params.businessId, discountCode, checkout.baseTotalPrice);
    const queueNote = checkout.productSummary || (typeof product_name === 'string' && product_name.trim() ? product_name.trim() : null);
    const normalizedPaymentMethod = payment_method === 'now' ? 'now' : 'later';

    const guestPasswordHash = await bcrypt.hash(`${entryId}:${guest_name.trim()}`, 6);
    const guestEmail = `guest.${entryId.replace(/-/g, '').substring(0, 12)}@guest.queueless.local`;

    await pool.query(
      'INSERT INTO users (id, name, email, password, phone, role) VALUES (?, ?, ?, ?, ?, ?)',
      [guestCustomerId, guest_name.trim(), guestEmail, guestPasswordHash, '', 'customer']
    );

    await pool.query(
      'INSERT INTO queue_entries (id, business_id, customer_id, customer_name, product_name, item_count, position, status, product_duration_minutes, total_price, total_cost, payment_method, discount_code, discount_amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        entryId,
        req.params.businessId,
        guestCustomerId,
        guest_name.trim(),
        queueNote,
        checkout.totalItemCount,
        position,
        'waiting',
        checkout.totalDurationMinutes,
        discount.finalTotalPrice,
        checkout.baseTotalCost,
        normalizedPaymentMethod,
        discount.appliedDiscountCode,
        discount.appliedDiscountAmount,
      ]
    );
    await pool.query(
      'INSERT INTO queues (id, business_id, waiting_count) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE waiting_count = waiting_count + 1',
      [uuidv4(), req.params.businessId]
    );

    // Decrement stock for each purchased item (only when stock > 0, i.e. tracked inventory)
    for (const item of checkout.normalizedItems) {
      await pool.query(
        'UPDATE products SET stock = GREATEST(stock - ?, 0) WHERE id = ? AND stock > 0',
        [item.quantity, item.productId]
      );
    }

    const [entry] = await pool.query('SELECT * FROM queue_entries WHERE id = ?', [entryId]);
    const [waiting] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [req.params.businessId]);
    const business = await getBusinessOwnerId(req.params.businessId);
    if (business?.owner_id) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: business.owner_id,
        title: 'New guest order in queue',
        body: `${guest_name.trim()} joined ${biz[0].name}${queueNote ? ` with ${queueNote}.` : '.'}`,
        type: 'queue_joined',
        entityType: 'queue_entry',
        entityId: entryId,
        metadata: { businessId: req.params.businessId, customerId: guestCustomerId, paymentMethod: normalizedPaymentMethod, isGuest: true },
      });
    }

    await broadcastQueueUpdate(req, req.params.businessId);

    res.status(201).json({
      success: true,
      entry: entry[0],
      businessName: biz[0].name,
      position,
      waitingCount: waiting[0].cnt,
      pricing: {
        subtotal: checkout.baseTotalPrice,
        discount_amount: discount.appliedDiscountAmount,
        total: discount.finalTotalPrice,
        discount_code: discount.appliedDiscountCode,
      },
    });
  } catch (err) { res.status(err.status || 500).json({ error: err.message }); }
});

// POST /api/queues/:businessId/pause — emergency pause
router.post('/:businessId/pause', authenticate, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE id = ? AND owner_id = ?', [req.params.businessId, req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);
    await pool.query(
      `INSERT INTO queues (id, business_id, waiting_count, serving_count, is_open, is_paused, paused_at)
       VALUES (?, ?, 0, 0, 1, 1, ?)
       ON DUPLICATE KEY UPDATE is_paused = 1, paused_at = VALUES(paused_at)`,
      [uuidv4(), req.params.businessId, now]
    );

    const io = req.app.get('io');
    if (io) io.to(`business:${req.params.businessId}`).emit('queue:paused', {
      message: 'The business has temporarily paused the queue. Your position is saved.'
    });
    const customerIds = await getActiveCustomerIdsForBusiness(req.params.businessId);
    await createNotifications({
      pool,
      io: req.app.get('io'),
      userIds: customerIds,
      title: 'Queue paused',
      body: 'The business paused the queue temporarily. Your position is still saved.',
      type: 'queue_paused',
      entityType: 'business',
      entityId: req.params.businessId,
      metadata: { businessId: req.params.businessId },
    });

    await broadcastQueueUpdate(req, req.params.businessId);
    res.json({ success: true, paused: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/queues/:businessId/resume — resume paused queue
router.post('/:businessId/resume', authenticate, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE id = ? AND owner_id = ?', [req.params.businessId, req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    const [queueRow] = await pool.query('SELECT paused_at FROM queues WHERE business_id = ?', [req.params.businessId]);
    let pausedMinutes = 0;
    if (queueRow[0] && queueRow[0].paused_at) {
      pausedMinutes = Math.round((Date.now() - new Date(queueRow[0].paused_at).getTime()) / 60000);
    }

    await pool.query(
      `INSERT INTO queues (id, business_id, waiting_count, serving_count, is_open, is_paused, paused_at)
       VALUES (?, ?, 0, 0, 1, 0, NULL)
       ON DUPLICATE KEY UPDATE is_paused = 0, paused_at = NULL`,
      [uuidv4(), req.params.businessId]
    );

    if (pausedMinutes > 0) {
      await pool.query(
        "UPDATE appointments SET date_time = DATE_ADD(date_time, INTERVAL ? MINUTE) WHERE business_id = ? AND status IN ('pending','confirmed') AND date_time >= NOW()",
        [pausedMinutes, req.params.businessId]
      );
    }

    const io = req.app.get('io');
    if (io) io.to(`business:${req.params.businessId}`).emit('queue:resumed', {
      message: pausedMinutes > 0
        ? `Queue resumed. Appointments shifted by ${pausedMinutes} minute(s).`
        : 'Queue has resumed.',
      shiftedMinutes: pausedMinutes,
    });
    const customerIds = await getActiveCustomerIdsForBusiness(req.params.businessId);
    await createNotifications({
      pool,
      io: req.app.get('io'),
      userIds: customerIds,
      title: 'Queue resumed',
      body: pausedMinutes > 0
        ? `The business resumed the queue and shifted future appointments by ${pausedMinutes} minute(s).`
        : 'The business resumed the queue.',
      type: 'queue_resumed',
      entityType: 'business',
      entityId: req.params.businessId,
      metadata: { businessId: req.params.businessId, shiftedMinutes: pausedMinutes },
    });

    await broadcastQueueUpdate(req, req.params.businessId);
    res.json({ success: true, paused: false, shiftedMinutes: pausedMinutes });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
