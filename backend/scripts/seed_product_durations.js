const { pool } = require('../db');

async function main() {
  await pool.query(
    `UPDATE products
     SET duration_minutes = CASE id
       WHEN 'p1' THEN 4
       WHEN 'p2' THEN 5
       WHEN 's1' THEN 45
       WHEN 's2' THEN 20
       WHEN 's3' THEN 25
       WHEN 's4' THEN 30
       WHEN 's5' THEN 20
       ELSE duration_minutes
     END
     WHERE id IN ('p1','p2','s1','s2','s3','s4','s5')
       AND (duration_minutes IS NULL OR duration_minutes = 0)`
  );
  console.log('Product durations seeded');
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
