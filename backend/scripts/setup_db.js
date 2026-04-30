const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function setupDatabase() {
  let connection;
  try {
    // Connect without specifying a database first
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      multipleStatements: true,
    });

    console.log('✅ Connected to MySQL server.');
    
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');

    console.log('📦 Running schema setup...');
    await connection.query(schema);
    console.log('✅ Database and tables created successfully!');
    console.log('✅ Seed data inserted!');
    console.log('\n🚀 You can now start the backend:');
    console.log('   cd backend && node server.js\n');

  } catch (err) {
    console.error('❌ Error setting up database:', err.message);
    process.exit(1);
  } finally {
    if (connection) await connection.end();
  }
}

setupDatabase();
