const { pool } = require('../db');

async function fetchJson(url, options) {
  const response = await fetch(url, options);
  const text = await response.text();
  let data = null;

  try {
    data = text ? JSON.parse(text) : null;
  } catch (_) {
    data = text;
  }

  if (!response.ok) {
    throw new Error(typeof data === 'object' && data && data.error ? data.error : `HTTP ${response.status}`);
  }

  return data;
}

async function cleanupAppointment(appointmentId) {
  const [rows] = await pool.query('SELECT slot_id, customer_id FROM appointments WHERE id = ? LIMIT 1', [appointmentId]);
  if (!rows.length) {
    return { cleaned: false, reason: 'appointment-not-found' };
  }

  const appointment = rows[0];
  await pool.query('DELETE FROM appointments WHERE id = ?', [appointmentId]);
  if (appointment.slot_id) {
    await pool.query('UPDATE time_slots SET is_booked = 0 WHERE id = ?', [appointment.slot_id]);
  }
  if (appointment.customer_id) {
    await pool.query('DELETE FROM users WHERE id = ?', [appointment.customer_id]);
  }

  return {
    cleaned: true,
    slotId: appointment.slot_id || null,
    customerId: appointment.customer_id || null,
  };
}

async function cleanupStaleTestAppointments(businessId, guestName) {
  const [rows] = await pool.query(
    'SELECT id FROM appointments WHERE business_id = ? AND customer_name = ?',
    [businessId, guestName]
  );

  const cleaned = [];
  for (const row of rows) {
    cleaned.push(await cleanupAppointment(row.id));
  }
  return cleaned;
}

async function main() {
  const businessId = 'b2';
  const date = '2026-04-18';
  const guestName = 'Copilot Slot Filter Test';

  let createdAppointmentId = null;

  try {
    const staleCleanup = await cleanupStaleTestAppointments(businessId, guestName);
    const allBefore = await fetchJson(`http://localhost:3000/api/appointments/slots?businessId=${businessId}&date=${date}&availableOnly=0`);
    const openBefore = await fetchJson(`http://localhost:3000/api/appointments/slots?businessId=${businessId}&date=${date}&availableOnly=1`);
    const products = await fetchJson(`http://localhost:3000/api/products?businessId=${businessId}`);

    if (!Array.isArray(products) || products.length === 0) {
      throw new Error('No services found for appointment test business');
    }
    if (!Array.isArray(openBefore) || openBefore.length === 0) {
      throw new Error('No open slots found for appointment test business');
    }

    const service = products[0];
    const slot = openBefore[0];

    const booking = await fetchJson('http://localhost:3000/api/appointments/guest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        business_id: businessId,
        guest_name: guestName,
        service_id: service.id,
        service_name: service.name,
        slot_id: slot.id,
        date_time: slot.start_time,
      }),
    });

    createdAppointmentId = booking.id;

    const allAfter = await fetchJson(`http://localhost:3000/api/appointments/slots?businessId=${businessId}&date=${date}&availableOnly=0`);
    const openAfter = await fetchJson(`http://localhost:3000/api/appointments/slots?businessId=${businessId}&date=${date}&availableOnly=1`);

    const result = {
      staleCleanups: staleCleanup.length,
      appointmentId: booking.id,
      bookedSlotId: slot.id,
      allBefore: Array.isArray(allBefore) ? allBefore.length : 0,
      openBefore: Array.isArray(openBefore) ? openBefore.length : 0,
      allAfter: Array.isArray(allAfter) ? allAfter.length : 0,
      openAfter: Array.isArray(openAfter) ? openAfter.length : 0,
      bookedSlotStillInAll: Array.isArray(allAfter) ? allAfter.some((item) => item.id === slot.id) : false,
      bookedSlotHiddenFromOpen: Array.isArray(openAfter) ? !openAfter.some((item) => item.id === slot.id) : false,
    };

    console.log(JSON.stringify(result, null, 2));
  } finally {
    if (createdAppointmentId) {
      const cleanup = await cleanupAppointment(createdAppointmentId);
      console.log(JSON.stringify({ cleanup }, null, 2));
    }
    await pool.end();
  }
}

main().catch(async (error) => {
  console.error(error && error.stack ? error.stack : String(error));
  try {
    await pool.end();
  } catch (_) {
    // Ignore shutdown errors in failure path.
  }
  process.exit(1);
});