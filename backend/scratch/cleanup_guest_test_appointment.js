async function main() {
  const appointmentId = process.argv[2];
  if (!appointmentId) {
    throw new Error('Usage: node cleanup_guest_test_appointment.js <appointmentId>');
  }

  process.chdir('c:/Users/tunao/Desktop/QueuelessProject/backend');
  const { pool } = require(process.cwd() + '/db');

  const [rows] = await pool.query('SELECT slot_id, customer_id, business_id FROM appointments WHERE id = ? LIMIT 1', [appointmentId]);
  if (rows.length === 0) {
    console.log(JSON.stringify({ cleaned: false, reason: 'appointment-not-found' }));
    await pool.end();
    return;
  }

  const appointment = rows[0];

  await pool.query('DELETE FROM appointments WHERE id = ?', [appointmentId]);
  if (appointment.slot_id) {
    await pool.query('UPDATE time_slots SET is_booked = 0 WHERE id = ?', [appointment.slot_id]);
  }
  if (appointment.customer_id) {
    await pool.query('DELETE FROM users WHERE id = ?', [appointment.customer_id]);
  }

  const [slotRows] = appointment.slot_id
    ? await pool.query('SELECT is_booked FROM time_slots WHERE id = ? LIMIT 1', [appointment.slot_id])
    : [[]];

  console.log(JSON.stringify({
    cleaned: true,
    appointmentId,
    slotId: appointment.slot_id || null,
    customerId: appointment.customer_id || null,
    slotBooked: slotRows[0] ? slotRows[0].is_booked : null,
  }));

  await pool.end();
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});