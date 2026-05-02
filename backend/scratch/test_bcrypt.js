const bcrypt = require('bcryptjs');

async function test() {
  const pwd = '123456';
  const hash = '$2a$10$X/qsJ0TZh6fCt9nHbg0ZnuETCbJ2kkuXL32m6kW/ZH7q.csFGnb7i';
  const match = await bcrypt.compare(pwd, hash);
  console.log(`Password: ${pwd}`);
  console.log(`Hash: ${hash}`);
  console.log(`Match: ${match}`);
  
  const newHash = await bcrypt.hash(pwd, 10);
  console.log(`New Hash for "123456": ${newHash}`);
}

test();
