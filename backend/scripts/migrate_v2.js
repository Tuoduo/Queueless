const { pool } = require('../db');

async function migrate() {
  const stmts = [
    'ALTER TABLE products ADD COLUMN duration_minutes INT NOT NULL DEFAULT 0',
    'ALTER TABLE queue_entries ADD COLUMN product_duration_minutes INT NOT NULL DEFAULT 0',
    'ALTER TABLE queue_entries ADD COLUMN total_price DECIMAL(10,2) DEFAULT 0.00',
    'ALTER TABLE queue_entries ADD COLUMN discount_code VARCHAR(50) DEFAULT NULL',
    'ALTER TABLE queue_entries ADD COLUMN discount_amount DECIMAL(10,2) DEFAULT 0.00',
  ];
  for (const sql of stmts) {
    try {
      await pool.query(sql);
      console.log('OK:', sql.substring(0, 60));
    } catch (e) {
      if (e.code === 'ER_DUP_FIELDNAME') {
        console.log('Already exists:', sql.split('ADD COLUMN ')[1]?.split(' ')[0]);
      } else {
        console.error('ERR:', e.message);
      }
    }
  }
  console.log('Migration complete');
  process.exit(0);
}

migrate();
