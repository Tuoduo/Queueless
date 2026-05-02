const express = require('express');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// GET /api/history — returns all completed queue entries + completed appointments for the authenticated user
router.get('/', authenticate, async (req, res) => {
  const customerId = req.user.id;
  try {
    // Completed queue entries
    const [queueRows] = await pool.query(
      `SELECT
         qe.id,
         'queue'             AS type,
         b.name              AS business_name,
         b.id                AS business_id,
         b.category,
         qe.product_name     AS service_name,
         CAST(COALESCE(qe.total_price, 0) AS DECIMAL(10,2)) + 0      AS final_price,
         qe.discount_code,
         CAST(COALESCE(qe.discount_amount, 0) AS DECIMAL(10,2)) + 0  AS discount_amount,
         COALESCE(qe.completed_at, qe.joined_at)                      AS completed_at,
         CAST(COALESCE(qe.total_price, 0) AS DECIMAL(10,2)) +
           CAST(COALESCE(qe.discount_amount, 0) AS DECIMAL(10,2))    AS original_price,
         r.rating            AS user_rating,
         r.comment           AS user_comment
       FROM queue_entries qe
       JOIN businesses b ON qe.business_id = b.id
       LEFT JOIN ratings r ON r.entry_id = qe.id
       WHERE qe.customer_id = ? AND qe.status = 'done'
       ORDER BY COALESCE(qe.completed_at, qe.joined_at) DESC`,
      [customerId]
    );

    // Completed appointments
    const [apptRows] = await pool.query(
      `SELECT
         a.id,
         'appointment'       AS type,
         COALESCE(a.business_name, b.name) AS business_name,
         b.id                AS business_id,
         b.category,
         COALESCE(a.service_name, a.notes) AS service_name,
         CAST(COALESCE(a.final_price, 0) AS DECIMAL(10,2)) + 0        AS final_price,
         a.discount_code,
         CAST(COALESCE(a.discount_amount, 0) AS DECIMAL(10,2)) + 0    AS discount_amount,
         COALESCE(a.date_time, a.created_at)                           AS completed_at,
         COALESCE(
           CAST(COALESCE(a.final_price, 0) AS DECIMAL(10,2)) +
             CAST(COALESCE(a.discount_amount, 0) AS DECIMAL(10,2)),
           CAST(COALESCE(p.price, 0) AS DECIMAL(10,2))
         )                   AS original_price,
         r.rating            AS user_rating,
         r.comment           AS user_comment
       FROM appointments a
       JOIN businesses b ON a.business_id = b.id
       LEFT JOIN products p ON p.business_id = a.business_id AND p.name = a.service_name
       LEFT JOIN ratings r ON r.entry_id = a.id
       WHERE a.customer_id = ? AND a.status = 'completed'
       ORDER BY a.created_at DESC`,
      [customerId]
    );

    // Normalise numeric fields so the Flutter client always gets numbers, never strings
    const normalise = (row) => ({
      ...row,
      final_price:      parseFloat(row.final_price)      || 0,
      original_price:   parseFloat(row.original_price)   || 0,
      discount_amount:  parseFloat(row.discount_amount)  || 0,
      user_rating:      row.user_rating != null ? parseInt(row.user_rating) : null,
    });

    // Merge and sort by date descending
    const all = [...queueRows.map(normalise), ...apptRows.map(normalise)].sort((a, b) => {
      const da = a.completed_at ? new Date(a.completed_at) : new Date(0);
      const db = b.completed_at ? new Date(b.completed_at) : new Date(0);
      return db - da;
    });

    res.json(all);
  } catch (err) {
    console.error('[history] GET /history error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
