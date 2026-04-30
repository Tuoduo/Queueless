const mysql = require('mysql2/promise');
require('dotenv').config();

async function updatePasswords() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  const correctHash = '$2a$10$t/gZWqKFfmby8/YCl/LmL.iVjIMKZzW2.3srOK2eUMGTB/rFmjGp6';
  
  console.log('🔄 Updating sample user passwords...');
  const [result] = await connection.query(
    'UPDATE users SET password = ? WHERE email IN (?, ?, ?, ?, ?)',
    [correctHash, 'customer@test.com', 'business@test.com', 'hafize@test.com', 'mahmut@test.com', 'ahmet@test.com']
  );
  
  console.log(`✅ Updated ${result.affectedRows} users.`);
  await connection.end();
}

updatePasswords().catch(console.error);
