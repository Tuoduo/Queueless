/**
 * Migration: change ratings table from per-business to per-entry
 * Run once: node backend/scripts/migrate_ratings_per_entry.js
 */
const { pool } = require('../db');

async function run() {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // 1. Clear stale per-business ratings (they showed on ALL orders from same business)
    await conn.query('DELETE FROM ratings WHERE 1');
    console.log('Cleared old ratings.');

    // 2. Add entry_id and entry_type columns if they don't exist yet
    const [cols] = await conn.query(`
      SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ratings'
      AND COLUMN_NAME IN ('entry_id', 'entry_type')
    `);
    const existingCols = cols.map((c) => c.COLUMN_NAME);

    if (!existingCols.includes('entry_id')) {
      await conn.query(`ALTER TABLE ratings ADD COLUMN entry_id VARCHAR(36) NULL AFTER customer_id`);
      console.log('Added entry_id column.');
    }
    if (!existingCols.includes('entry_type')) {
      await conn.query(`ALTER TABLE ratings ADD COLUMN entry_type VARCHAR(20) NULL AFTER entry_id`);
      console.log('Added entry_type column.');
    }

    // 3. Drop old unique key unique_rating (business_id, customer_id) if it exists
    //    MySQL won't drop it if FK constraints reference the indexed columns,
    //    so we must drop and re-add the FK constraints around it.
    const [indexes] = await conn.query(`
      SELECT INDEX_NAME FROM INFORMATION_SCHEMA.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ratings'
      AND INDEX_NAME = 'unique_rating'
    `);
    if (indexes.length > 0) {
      // Find FK constraints on ratings table
      const [fks] = await conn.query(`
        SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ratings'
        AND CONSTRAINT_TYPE = 'FOREIGN KEY'
      `);
      // Drop all FK constraints
      for (const fk of fks) {
        await conn.query(`ALTER TABLE ratings DROP FOREIGN KEY \`${fk.CONSTRAINT_NAME}\``);
        console.log(`Dropped FK: ${fk.CONSTRAINT_NAME}`);
      }
      // Now drop the unique index
      await conn.query(`ALTER TABLE ratings DROP INDEX unique_rating`);
      console.log('Dropped old unique_rating index.');
      // Re-add the FK constraints
      await conn.query(`ALTER TABLE ratings ADD CONSTRAINT fk_ratings_business FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE`);
      await conn.query(`ALTER TABLE ratings ADD CONSTRAINT fk_ratings_customer FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE`);
      console.log('Re-added FK constraints.');
    }

    // 4. Add new unique key on entry_id (one rating per order)
    const [newIdxCheck] = await conn.query(`
      SELECT INDEX_NAME FROM INFORMATION_SCHEMA.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ratings'
      AND INDEX_NAME = 'unique_rating_per_entry'
    `);
    if (newIdxCheck.length === 0) {
      await conn.query(`ALTER TABLE ratings ADD UNIQUE KEY unique_rating_per_entry (entry_id)`);
      console.log('Added unique_rating_per_entry index.');
    }

    await conn.commit();
    console.log('Migration complete.');
  } catch (err) {
    await conn.rollback();
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    conn.release();
    process.exit(0);
  }
}

run();
