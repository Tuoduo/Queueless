async function main() {
  process.chdir('c:/Users/tunao/Desktop/QueuelessProject/backend');
  const { pool } = require(process.cwd() + '/db');
  const entryId = '739932da-ab2b-453a-a546-6a75f3d06576';
  const customerId = 'ff18ab15-9a33-449b-9965-6cea34d01e61';
  const productId = '001fd964-3bd6-463a-a206-cb4dcc98d22a';
  const businessId = '0c1a762f-73e3-4565-9da0-39920ede2fd4';

  await pool.query('DELETE FROM queue_entries WHERE id = ?', [entryId]);
  await pool.query('DELETE FROM users WHERE id = ?', [customerId]);
  await pool.query('UPDATE products SET stock = stock + 1 WHERE id = ? AND stock > 0', [productId]);

  const [waiting] = await pool.query(
    "SELECT COUNT(*) AS cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'",
    [businessId]
  );

  await pool.query('UPDATE queues SET waiting_count = ? WHERE business_id = ?', [waiting[0].cnt || 0, businessId]);

  console.log(JSON.stringify({ cleaned: true, waitingCount: waiting[0].cnt || 0 }));
  await pool.end();
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});