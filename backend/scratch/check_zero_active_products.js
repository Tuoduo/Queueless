const { pool } = require('../db');
(async () => {
  try {
    const sql = `
      SELECT b.id, b.name, b.service_type,
             COUNT(CASE WHEN p.is_available = 1 AND p.is_off_sale = 0 THEN 1 END) AS active_product_count
      FROM businesses b
      LEFT JOIN products p ON p.business_id = b.id
      WHERE b.service_type IN ('queue','both')
      GROUP BY b.id, b.name, b.service_type
      HAVING active_product_count = 0
      ORDER BY b.id ASC`;
    const [rows] = await pool.query(sql);
    console.log(JSON.stringify(rows, null, 2));
    await pool.end();
  } catch (err) {
    console.error('QUERY_ERROR');
    console.error(err && (err.stack || err.message || String(err)));
    process.exit(1);
  }
})();
