const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '+00:00',
});

async function testConnection() {
  try {
    const conn = await pool.getConnection();
    console.log('✅ MySQL connected successfully');
    // Run schema migrations for new columns (ignore ER_DUP_COLUMN_NAME if already added)
    const migrations = [
      `ALTER TABLE users ADD COLUMN notifications_enabled TINYINT(1) NOT NULL DEFAULT 1`,
      `ALTER TABLE businesses MODIFY COLUMN category ENUM('bakery','barber','restaurant','clinic','bank','repair','beauty','dentist','gym','pharmacy','grocery','government','cafe','vet','other') NOT NULL DEFAULT 'other'`,
      `ALTER TABLE businesses ADD COLUMN latitude DECIMAL(10,7) NULL`,
      `ALTER TABLE businesses ADD COLUMN longitude DECIMAL(10,7) NULL`,
      `ALTER TABLE businesses ADD COLUMN approval_status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'approved'`,
      `ALTER TABLE queue_entries ADD COLUMN item_count INT NOT NULL DEFAULT 1`,
      `ALTER TABLE queue_entries ADD COLUMN payment_method ENUM('later','now') NOT NULL DEFAULT 'later'`,
      `ALTER TABLE queue_entries ADD COLUMN started_at DATETIME NULL`,
      `ALTER TABLE queue_entries ADD COLUMN completed_at DATETIME NULL`,
      `ALTER TABLE queue_entries ADD COLUMN service_duration_seconds INT NULL`,
      `ALTER TABLE queue_entries ADD COLUMN arrival_confirmed_at DATETIME NULL`,
      `ALTER TABLE queue_entries ADD COLUMN arrival_distance_meters INT NULL`,
      `ALTER TABLE queues ADD COLUMN is_paused TINYINT(1) NOT NULL DEFAULT 0`,
      `ALTER TABLE queues ADD COLUMN paused_at DATETIME NULL`,
      `ALTER TABLE ratings ADD COLUMN comment TEXT`,
      `ALTER TABLE ratings ADD COLUMN products_purchased TEXT`,
      `ALTER TABLE products ADD COLUMN cost DECIMAL(10,2) NOT NULL DEFAULT 0.00`,
      `ALTER TABLE queue_entries ADD COLUMN total_cost DECIMAL(10,2) DEFAULT 0.00`,
      `CREATE TABLE IF NOT EXISTS business_chat_conversations (
        id VARCHAR(36) PRIMARY KEY,
        business_id VARCHAR(36) NOT NULL,
        customer_id VARCHAR(36) NOT NULL,
        owner_id VARCHAR(36) NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        last_message_at DATETIME NULL,
        UNIQUE KEY uniq_business_customer (business_id, customer_id),
        KEY idx_business_chat_business (business_id),
        KEY idx_business_chat_customer (customer_id),
        KEY idx_business_chat_owner (owner_id)
      )`,
      `CREATE TABLE IF NOT EXISTS business_chat_messages (
        id VARCHAR(36) PRIMARY KEY,
        conversation_id VARCHAR(36) NOT NULL,
        sender_id VARCHAR(36) NOT NULL,
        sender_role VARCHAR(32) NOT NULL,
        message TEXT NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY idx_business_chat_message_conversation (conversation_id),
        CONSTRAINT fk_business_chat_message_conversation
          FOREIGN KEY (conversation_id) REFERENCES business_chat_conversations(id)
          ON DELETE CASCADE
      )`,
      `CREATE TABLE IF NOT EXISTS business_chat_bans (
        id VARCHAR(36) PRIMARY KEY,
        business_id VARCHAR(36) NOT NULL,
        customer_id VARCHAR(36) NOT NULL,
        owner_id VARCHAR(36) NOT NULL,
        reason VARCHAR(255) NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_business_chat_ban (business_id, customer_id),
        KEY idx_business_chat_ban_business (business_id),
        KEY idx_business_chat_ban_customer (customer_id)
      )`,
      `CREATE TABLE IF NOT EXISTS notifications (
        id VARCHAR(36) PRIMARY KEY,
        recipient_id VARCHAR(36) NOT NULL,
        title VARCHAR(180) NOT NULL,
        body TEXT NOT NULL,
        type VARCHAR(48) NOT NULL DEFAULT 'general',
        entity_type VARCHAR(48) NULL,
        entity_id VARCHAR(36) NULL,
        metadata JSON NULL,
        is_read TINYINT(1) NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY idx_notifications_recipient (recipient_id),
        KEY idx_notifications_recipient_read (recipient_id, is_read),
        CONSTRAINT fk_notifications_recipient FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
      )`,
      `CREATE INDEX idx_businesses_owner ON businesses(owner_id)`,
      // Fix products that were incorrectly set to is_available=0 by the stock-based bug
      `UPDATE products SET is_available = 1 WHERE is_off_sale = 0`,
    ];
    for (const sql of migrations) {
      try {
        await conn.query(sql);
      } catch (e) {
        // ER_DUP_FIELDNAME = column already exists (safe to skip for ALTER ADD COLUMN)
        if (e.code === 'ER_DUP_FIELDNAME') continue;
        // For non-ALTER statements (UPDATE etc.), just log and continue
        console.warn('⚠️ Migration skipped:', e.message);
      }
    }
    conn.release();
  } catch (err) {
    console.error('❌ MySQL connection error:', err.message);
    process.exit(1);
  }
}

module.exports = { pool, testConnection };
