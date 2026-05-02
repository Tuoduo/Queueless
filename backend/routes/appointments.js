const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');
const { createNotification } = require('../utils/notifications');

const router = express.Router();

function createHttpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function normalizeDateTimeInput(value) {
  let candidate = value;

  if (Array.isArray(candidate)) {
    candidate = candidate[0];
  }

  if (candidate && typeof candidate === 'object' && !(candidate instanceof Date)) {
    if (candidate.date_time != null) {
      candidate = candidate.date_time;
    } else if (candidate.start_time != null) {
      candidate = candidate.start_time;
    } else if (candidate.value != null) {
      candidate = candidate.value;
    }
  }

  const parsed = candidate instanceof Date ? candidate : new Date(candidate);
  if (Number.isNaN(parsed.getTime())) {
    throw createHttpError(400, 'Invalid date_time value');
  }

  return parsed.toISOString().replace('T', ' ').slice(0, 19);
}

async function emitAppointmentUpdate(req, appointmentId) {
  const io = req.app.get('io');
  if (!io || !appointmentId) return;

  const [rows] = await pool.query(
    `SELECT a.*, p.price AS original_price, p.duration_minutes AS service_duration_minutes
     FROM appointments a
     LEFT JOIN products p ON p.business_id = a.business_id AND p.name = a.service_name
     WHERE a.id = ?`,
    [appointmentId]
  );

  if (rows.length === 0) return;

  const appointment = rows[0];
  io.to(`business:${appointment.business_id}`).emit('appointment:update', {
    appointment,
  });

  if (appointment.customer_id) {
    io.to(`user:${appointment.customer_id}`).emit('appointment:update', {
      appointment,
    });

    if (appointment.status === 'completed') {
      io.to(`user:${appointment.customer_id}`).emit('history:update', {
        type: 'appointment',
        appointmentId: appointment.id,
        businessId: appointment.business_id,
      });
    }
  }
}

async function loadSlotForMutation(slotId) {
  const [rows] = await pool.query(
    `SELECT ts.*, b.owner_id
     FROM time_slots ts
     JOIN businesses b ON b.id = ts.business_id
     WHERE ts.id = ?`,
    [slotId]
  );

  return rows[0] || null;
}

function canMutateSlot(user, slot) {
  if (!user || !slot) return false;
  if (user.role === 'admin') return true;
  return user.role === 'businessOwner' && slot.owner_id === user.id;
}

// GET /api/appointments/slots?businessId=xxx&date=YYYY-MM-DD
router.get('/slots', async (req, res) => {
  const { businessId, date, availableOnly } = req.query;
  if (!businessId || !date) return res.status(400).json({ error: 'businessId and date required' });

  try {
    const onlyAvailable = availableOnly === '1' || availableOnly === 'true';
    const now = new Date();
    const todayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
    const isToday = date === todayKey;

    const [existingRows] = await pool.query(
      'SELECT * FROM time_slots WHERE business_id = ? AND DATE(start_time) = ? ORDER BY start_time ASC',
      [businessId, date]
    );

    let rows = existingRows;

    // Auto-generate slots if none exist for this date
    if (rows.length === 0) {
      const generatedSlots = [];
      const baseDate = new Date(date);

      for (let hour = 9; hour < 18; hour++) {
        const id = uuidv4();
        const start = new Date(baseDate);
        start.setHours(hour, 0, 0, 0);
        const end = new Date(baseDate);
        end.setHours(hour + 1, 0, 0, 0);

        await pool.query(
          'INSERT INTO time_slots (id, business_id, start_time, end_time, is_booked) VALUES (?, ?, ?, ?, 0)',
          [id, businessId, start.toISOString().replace('T', ' ').slice(0, 19), end.toISOString().replace('T', ' ').slice(0, 19)]
        );

        generatedSlots.push({ id, business_id: businessId, start_time: start, end_time: end, is_booked: 0 });
      }
      rows = generatedSlots;
    }

    const visibleRows = rows.filter((slot) => {
      const isBooked = slot.is_booked === 1 || slot.is_booked === true;
      if (onlyAvailable && isBooked) return false;
      if (onlyAvailable && isToday) {
        return new Date(slot.start_time) > now;
      }
      return true;
    });

    res.json(visibleRows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/appointments/slots
router.post('/slots', authenticate, async (req, res) => {
  const { business_id, start_time, end_time } = req.body;
  try {
    const id = uuidv4();
    await pool.query(
      'INSERT INTO time_slots (id, business_id, start_time, end_time, is_booked) VALUES (?, ?, ?, ?, 0)',
      [id, business_id, start_time.replace('T', ' ').slice(0, 19), end_time.replace('T', ' ').slice(0, 19)]
    );
    const [row] = await pool.query('SELECT * FROM time_slots WHERE id = ?', [id]);
    res.status(201).json(row[0]);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// PUT /api/appointments/slots/:id
router.put('/slots/:id', authenticate, async (req, res) => {
  const { start_time, end_time } = req.body || {};

  if (!start_time || !end_time) {
    return res.status(400).json({ error: 'start_time and end_time required' });
  }

  try {
    const slot = await loadSlotForMutation(req.params.id);
    if (!slot) return res.status(404).json({ error: 'Time slot not found' });
    if (!canMutateSlot(req.user, slot)) return res.status(403).json({ error: 'Not allowed to edit this time slot' });
    if (slot.is_booked) return res.status(409).json({ error: 'Booked time slots cannot be edited' });

    const normalizedStart = normalizeDateTimeInput(start_time);
    const normalizedEnd = normalizeDateTimeInput(end_time);

    if (new Date(normalizedEnd) <= new Date(normalizedStart)) {
      return res.status(400).json({ error: 'End time must be after start time' });
    }

    await pool.query(
      'UPDATE time_slots SET start_time = ?, end_time = ? WHERE id = ?',
      [normalizedStart, normalizedEnd, req.params.id]
    );

    const [rows] = await pool.query('SELECT * FROM time_slots WHERE id = ?', [req.params.id]);
    res.json(rows[0]);
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

// DELETE /api/appointments/slots/:id
router.delete('/slots/:id', authenticate, async (req, res) => {
  try {
    const slot = await loadSlotForMutation(req.params.id);
    if (!slot) return res.status(404).json({ error: 'Time slot not found' });
    if (!canMutateSlot(req.user, slot)) return res.status(403).json({ error: 'Not allowed to delete this time slot' });
    if (slot.is_booked) return res.status(409).json({ error: 'Booked time slots cannot be deleted' });

    await pool.query('DELETE FROM time_slots WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message });
  }
});

// GET /api/appointments?customerId=xxx
router.get('/', authenticate, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT a.*, p.price AS original_price, p.duration_minutes AS service_duration_minutes
       FROM appointments a
       LEFT JOIN products p ON p.business_id = a.business_id AND p.name = a.service_name
       WHERE a.customer_id = ?
       ORDER BY a.date_time DESC`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET /api/appointments/business/:businessId (for owners)
router.get('/business/:businessId', authenticate, async (req, res) => {
  const { date } = req.query;
  try {
    let query = `SELECT a.*, p.price AS original_price, p.duration_minutes AS service_duration_minutes
                 FROM appointments a
                 LEFT JOIN products p ON p.business_id = a.business_id AND p.name = a.service_name
                 WHERE a.business_id = ?`;
    let params = [req.params.businessId];

    if (date) {
      query += ' AND DATE(a.date_time) = ?';
      params.push(date);
    }

    query += ' ORDER BY a.date_time ASC';
    const [rows] = await pool.query(query, params);
    res.json(rows);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/appointments/guest  (no auth — for QR scan guests)
router.post('/guest', async (req, res) => {
  const { business_id, guest_name, service_id, service_name, slot_id, date_time } = req.body;
  if (!business_id || !guest_name || !date_time) return res.status(400).json({ error: 'business_id, guest_name and date_time required' });

  try {
    const formattedDateTime = normalizeDateTimeInput(date_time);
    if (slot_id) {
      const [slot] = await pool.query('SELECT is_booked FROM time_slots WHERE id = ?', [slot_id]);
      if (slot.length > 0 && slot[0].is_booked) return res.status(409).json({ error: 'This time slot is already booked. Please choose a different time.' });
    }

    let finalPrice = null;
    if (service_id) {
      const [productRow] = await pool.query('SELECT price FROM products WHERE id = ? LIMIT 1', [service_id]);
      if (productRow.length > 0) finalPrice = parseFloat(productRow[0].price);
    }

    const [biz] = await pool.query('SELECT name FROM businesses WHERE id = ?', [business_id]);
    const id = uuidv4();
    const guestCustomerId = uuidv4();
    const trimmedGuestName = guest_name.trim();
    const guestPasswordHash = await bcrypt.hash(`${id}:${trimmedGuestName}`, 6);
    const guestEmail = `guest.${id.replace(/-/g, '').substring(0, 12)}@guest.queueless.local`;

    await pool.query(
      'INSERT INTO users (id, name, email, password, phone, role) VALUES (?, ?, ?, ?, ?, ?)',
      [guestCustomerId, trimmedGuestName, guestEmail, guestPasswordHash, '', 'customer']
    );

    await pool.query(
      'INSERT INTO appointments (id, business_id, business_name, customer_id, customer_name, slot_id, date_time, service_name, final_price) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, business_id, biz[0]?.name, guestCustomerId, trimmedGuestName, slot_id || null, formattedDateTime, service_name || null, finalPrice]
    );

    if (slot_id) {
      await pool.query('UPDATE time_slots SET is_booked = 1 WHERE id = ?', [slot_id]);
    }

    await emitAppointmentUpdate(req, id);
    res.status(201).json({ id, service_name, date_time: formattedDateTime, final_price: finalPrice });
  } catch (err) { res.status(err.status || 500).json({ error: err.message }); }
});

// POST /api/appointments (book appointment)
router.post('/', authenticate, async (req, res) => {
  const { business_id, slot_id, date_time, service_name, notes, discount_code } = req.body;
  if (!business_id || !date_time) return res.status(400).json({ error: 'business_id and date_time required' });

  try {
    const formattedDateTime = normalizeDateTimeInput(date_time);
    // Check if slot is booked
    if (slot_id) {
      const [slot] = await pool.query('SELECT is_booked FROM time_slots WHERE id = ?', [slot_id]);
      if (slot.length > 0 && slot[0].is_booked) return res.status(409).json({ error: 'This time slot is already booked. Please choose a different time.' });
    }

    // Duplicate service check: same customer, same business, same service → block (regardless of time)
    if (service_name) {
      const [existing] = await pool.query(
        "SELECT id FROM appointments WHERE customer_id = ? AND business_id = ? AND service_name = ? AND status NOT IN ('cancelled', 'completed')",
        [req.user.id, business_id, service_name]
      );
      if (existing.length > 0) {
        return res.status(409).json({ error: `You already have an active booking for "${service_name}". Please cancel it first or choose a different service.` });
      }
    }

    // Handle discount
    let discountAmount = 0;
    let finalPrice = null;
    
    // Get product price if service_name provided
    if (service_name) {
      const [productRow] = await pool.query(
        'SELECT price FROM products WHERE business_id = ? AND name = ? LIMIT 1',
        [business_id, service_name]
      );
      if (productRow.length > 0) {
        finalPrice = parseFloat(productRow[0].price);
      }
    }

    if (discount_code && finalPrice !== null) {
      const [discount] = await pool.query(
        'SELECT * FROM discounts WHERE business_id = ? AND code = ? AND is_active = 1 AND used_count < max_usage_count AND (expires_at IS NULL OR expires_at > NOW())',
        [business_id, discount_code.toUpperCase()]
      );
      if (discount.length === 0) {
        return res.status(400).json({ error: 'Invalid or expired coupon code' });
      }

      const d = discount[0];
      await pool.query('UPDATE discounts SET used_count = used_count + 1 WHERE id = ?', [d.id]);
      discountAmount = d.type === 'percentage'
        ? parseFloat((finalPrice * d.value / 100).toFixed(2))
        : Math.min(parseFloat(d.value || 0), finalPrice);
      finalPrice = parseFloat((finalPrice - discountAmount).toFixed(2));
    }

    const [biz] = await pool.query('SELECT name FROM businesses WHERE id = ?', [business_id]);
    const [user] = await pool.query('SELECT name FROM users WHERE id = ?', [req.user.id]);

    const id = uuidv4();
    await pool.query(
      'INSERT INTO appointments (id, business_id, business_name, customer_id, customer_name, slot_id, date_time, service_name, notes, discount_code, discount_amount, final_price) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, business_id, biz[0]?.name, req.user.id, user[0]?.name, slot_id || null, formattedDateTime, service_name || null, notes || null, discount_code || null, discountAmount, finalPrice]
    );

    // Mark slot as booked
    if (slot_id) {
      await pool.query('UPDATE time_slots SET is_booked = 1 WHERE id = ?', [slot_id]);
    }

    const [row] = await pool.query(
      `SELECT a.*, p.price AS original_price, p.duration_minutes AS service_duration_minutes
       FROM appointments a
       LEFT JOIN products p ON p.business_id = a.business_id AND p.name = a.service_name
       WHERE a.id = ?`,
      [id]
    );
    const [bizOwnerRows] = await pool.query('SELECT owner_id, name FROM businesses WHERE id = ?', [business_id]);
    if (bizOwnerRows[0]?.owner_id) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: bizOwnerRows[0].owner_id,
        title: 'New appointment booked',
        body: `${user[0]?.name || 'A customer'} booked ${service_name || 'an appointment'} at ${bizOwnerRows[0].name || 'your business'}.`,
        type: 'appointment_booked',
        entityType: 'appointment',
        entityId: id,
        metadata: { businessId: business_id },
      });
    }
    await emitAppointmentUpdate(req, id);
    res.status(201).json(row[0]);
  } catch (err) { res.status(err.status || 500).json({ error: err.message }); }
});

// PUT /api/appointments/:id/status
router.put('/:id/status', authenticate, async (req, res) => {
  const { status } = req.body;
  try {
    const [rows] = await pool.query('SELECT business_name, customer_id, service_name FROM appointments WHERE id = ?', [req.params.id]);
    await pool.query('UPDATE appointments SET status = ? WHERE id = ?', [status, req.params.id]);
    if (rows[0]?.customer_id) {
      const statusLabel = status.replaceAll('_', ' ');
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: rows[0].customer_id,
        title: 'Appointment updated',
        body: `${rows[0].business_name || 'Your business'} changed ${rows[0].service_name || 'your appointment'} to ${statusLabel}.`,
        type: 'appointment_status',
        entityType: 'appointment',
        entityId: req.params.id,
        metadata: { status },
      });
    }
    await emitAppointmentUpdate(req, req.params.id);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// DELETE /api/appointments/:id
router.delete('/:id', authenticate, async (req, res) => {
  try {
    const [appt] = await pool.query('SELECT slot_id, business_id, business_name, service_name FROM appointments WHERE id = ? AND customer_id = ?', [req.params.id, req.user.id]);
    if (appt.length === 0) return res.status(404).json({ error: 'Not found' });

    await pool.query("UPDATE appointments SET status = 'cancelled' WHERE id = ?", [req.params.id]);
    if (appt[0].slot_id) {
      await pool.query('UPDATE time_slots SET is_booked = 0 WHERE id = ?', [appt[0].slot_id]);
    }
    const [bizRows] = await pool.query('SELECT owner_id FROM businesses WHERE id = ?', [appt[0].business_id]);
    if (bizRows[0]?.owner_id) {
      await createNotification({
        pool,
        io: req.app.get('io'),
        userId: bizRows[0].owner_id,
        title: 'Appointment cancelled',
        body: `${req.user?.name || 'A customer'} cancelled ${appt[0].service_name || 'an appointment'} at ${appt[0].business_name || 'your business'}.`,
        type: 'appointment_cancelled',
        entityType: 'appointment',
        entityId: req.params.id,
        metadata: { businessId: appt[0].business_id },
      });
    }
    await emitAppointmentUpdate(req, req.params.id);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;
