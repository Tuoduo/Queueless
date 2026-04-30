f = open(r'c:\Users\tunao\Desktop\QueuelessProject\backend\routes\queues.js', encoding='utf-8').readlines()
print('Total lines:', len(f))

# Find first module.exports
first_exports = next(i for i,l in enumerate(f) if 'module.exports = router' in l)
print('First module.exports at line:', first_exports + 1)

guest_and_pause = """
// POST /api/queues/:businessId/join-guest — join queue without authentication (QR scan)
router.post('/:businessId/join-guest', async (req, res) => {
  const { guest_name, product_name } = req.body;
  if (!guest_name || !guest_name.trim()) return res.status(400).json({ error: 'guest_name required' });
  try {
    const [biz] = await pool.query('SELECT id, name, service_type, is_active FROM businesses WHERE id = ?', [req.params.businessId]);
    if (biz.length === 0) return res.status(404).json({ error: 'Business not found' });
    if (!biz[0].is_active) return res.status(403).json({ error: 'Business is currently closed' });
    if (!['queue', 'both'].includes(biz[0].service_type)) return res.status(403).json({ error: 'This business does not use queue service' });

    const [queueRow] = await pool.query('SELECT is_paused FROM queues WHERE business_id = ?', [req.params.businessId]);
    if (queueRow[0] && queueRow[0].is_paused) return res.status(403).json({ error: 'Queue is temporarily paused. Your position will be saved once resumed.' });

    const [pos] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [req.params.businessId]);
    const position = (pos[0].cnt || 0) + 1;
    const entryId = uuidv4();
    const guestCustomerId = 'guest_' + entryId.replace(/-/g, '').substring(0, 8);

    await pool.query(
      'INSERT INTO queue_entries (id, business_id, customer_id, customer_name, product_name, position, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [entryId, req.params.businessId, guestCustomerId, guest_name.trim(), product_name || null, position, 'waiting']
    );
    await pool.query(
      'INSERT INTO queues (id, business_id, waiting_count) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE waiting_count = waiting_count + 1',
      [uuidv4(), req.params.businessId]
    );

    const [entry] = await pool.query('SELECT * FROM queue_entries WHERE id = ?', [entryId]);
    const [waiting] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [req.params.businessId]);

    try {
      const io = req.app.get('io');
      if (io) {
        const [entries] = await pool.query("SELECT * FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving') ORDER BY position ASC", [req.params.businessId]);
        io.to(`business:${req.params.businessId}`).emit('queue:update', { queue: queueRow[0] || {}, entries, avgServiceSeconds: 300 });
      }
    } catch (_) {}

    res.status(201).json({
      success: true,
      entry: entry[0],
      businessName: biz[0].name,
      position,
      waitingCount: waiting[0].cnt,
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// POST /api/queues/:businessId/pause — emergency pause
router.post('/:businessId/pause', authenticate, async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT id FROM businesses WHERE id = ? AND owner_id = ?', [req.params.businessId, req.user.id]);
    if (biz.length === 0) return res.status(403).json({ error: 'Forbidden' });

    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);
    await pool.query('UPDATE queues SET is_paused = 1, paused_at = ? WHERE business_id = ?', [now, req.params.businessId]);

    const io = req.app.get('io');
    if (io) io.to(`business:${req.params.businessId}`).emit('queue:paused', {
      message: 'The business has temporarily paused the queue. Your position is saved.'
    });

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

    await pool.query('UPDATE queues SET is_paused = 0, paused_at = NULL WHERE business_id = ?', [req.params.businessId]);

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

    await broadcastQueueUpdate(req, req.params.businessId);
    res.json({ success: true, paused: false, shiftedMinutes: pausedMinutes });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

"""

with open(r'c:\Users\tunao\Desktop\QueuelessProject\backend\routes\queues.js', 'w', encoding='utf-8') as out:
    out.writelines(f[:first_exports])
    out.write(guest_and_pause)
    out.write('module.exports = router;\n')

print('Done, wrote', first_exports, 'original lines + new endpoints')
