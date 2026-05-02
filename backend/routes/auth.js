const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { notifyAdmins } = require('../utils/notifications');
const { authenticate } = require('../middleware/auth');
const { emitBusinessUpdate } = require('../utils/business_updates');

const router = express.Router();
const BUSINESS_CATEGORIES = new Set(['bakery', 'barber', 'restaurant', 'clinic', 'bank', 'repair', 'beauty', 'dentist', 'gym', 'pharmacy', 'grocery', 'government', 'cafe', 'vet', 'other']);
const SERVICE_TYPES = new Set(['queue', 'appointment', 'both']);

function mapUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role,
    notifications_enabled: user.notifications_enabled !== 0 && user.notifications_enabled !== false,
  };
}

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

  try {
    console.log(`AUTH: Login Attempt: Email=${email}, PwdLength=${password?.length}`);
    const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
    if (rows.length === 0) {
      console.log('AUTH: Login Fail: User not found in DB');
      return res.status(404).json({ error: 'No account found for this email address.' });
    }

    const user = rows[0];
    console.log(`AUTH: User Found: ID=${user.id}, DB_PWD_HASH=${user.password}`);

    // Check if user is banned
    if (user.is_banned) {
      console.log('AUTH: Login Fail: User is banned');
      return res.status(403).json({ error: 'Your account has been suspended. Reason: ' + (user.ban_reason || 'Policy violation') });
    }
    
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      console.log('AUTH: Login Fail: Password mismatch');
      return res.status(401).json({ error: 'Incorrect password. Please try again.' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.json({
      token,
      user: mapUser(user),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/auth/register
router.post('/register', async (req, res) => {
  const { name, email, password, phone, role, businessName, businessCategory, serviceType, businessAddress } = req.body;
  if (!name || !email || !password || !role) return res.status(400).json({ error: 'Missing required fields' });

  try {
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length > 0) return res.status(409).json({ error: 'Email already registered' });

    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = uuidv4();

    await pool.query(
      'INSERT INTO users (id, name, email, password, phone, role) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, name, email, hashedPassword, phone || '', role]
    );

    // If business owner, create business automatically
    if (role === 'businessOwner' && businessName) {
      const normalizedCategory = BUSINESS_CATEGORIES.has(businessCategory) ? businessCategory : 'other';
      const normalizedServiceType = SERVICE_TYPES.has(serviceType) ? serviceType : 'queue';
      const businessId = uuidv4();
      await pool.query(
        'INSERT INTO businesses (id, owner_id, name, description, category, service_type, address, is_active, approval_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [businessId, userId, businessName, `A new ${normalizedCategory} business.`, normalizedCategory, normalizedServiceType, businessAddress || '', 0, 'pending']
      );
      const [businessRows] = await pool.query('SELECT * FROM businesses WHERE id = ?', [businessId]);
      await notifyAdmins({
        pool,
        io: req.app.get('io'),
        title: 'New business awaiting approval',
        body: `${businessName} was registered and is ready for admin review.`,
        type: 'business_pending',
        entityType: 'business',
        entityId: businessId,
        metadata: { businessId, ownerId: userId, businessName },
      });
      await emitBusinessUpdate({ io: req.app.get('io'), business: businessRows[0] });
    }

    const token = jwt.sign({ id: userId, email, role }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });

    res.status(201).json({
      token,
      user: { id: userId, name, email, phone: phone || '', role, notifications_enabled: true },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/auth/me  (verify token)
router.get('/me', async (req, res) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'No token provided' });

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const [rows] = await pool.query('SELECT id, name, email, phone, role, notifications_enabled FROM users WHERE id = ?', [decoded.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: mapUser(rows[0]) });
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// PUT /api/auth/profile  (update own profile)
router.put('/profile', async (req, res) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'No token provided' });

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const { name, email, phone, password } = req.body;

    if (!name || !email) return res.status(400).json({ error: 'Name and email are required' });

    // Check email uniqueness (exclude self)
    const [existing] = await pool.query('SELECT id FROM users WHERE email = ? AND id != ?', [email, decoded.id]);
    if (existing.length > 0) return res.status(409).json({ error: 'Email already in use by another account' });

    if (password) {
      // Require current password for password changes
      const { currentPassword } = req.body;
      if (!currentPassword) {
        return res.status(400).json({ error: 'Current password is required to set a new password' });
      }
      const [userRows] = await pool.query('SELECT password FROM users WHERE id = ?', [decoded.id]);
      if (userRows.length === 0) return res.status(404).json({ error: 'User not found' });
      const pwMatch = await bcrypt.compare(currentPassword, userRows[0].password);
      if (!pwMatch) {
        return res.status(401).json({ error: 'Current password is incorrect' });
      }
      const hashed = await bcrypt.hash(password, 10);
      await pool.query('UPDATE users SET name=?, email=?, phone=?, password=? WHERE id=?', [name, email, phone || '', hashed, decoded.id]);
    } else {
      await pool.query('UPDATE users SET name=?, email=?, phone=? WHERE id=?', [name, email, phone || '', decoded.id]);
    }

    const [rows] = await pool.query('SELECT id, name, email, phone, role, notifications_enabled FROM users WHERE id = ?', [decoded.id]);
    res.json({ user: mapUser(rows[0]) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/preferences/notifications', authenticate, async (req, res) => {
  try {
    const enabled = req.body?.enabled !== false;
    await pool.query('UPDATE users SET notifications_enabled = ? WHERE id = ?', [enabled ? 1 : 0, req.user.id]);
    const [rows] = await pool.query('SELECT id, name, email, phone, role, notifications_enabled FROM users WHERE id = ?', [req.user.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: mapUser(rows[0]) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/auth/account  (delete own account)
router.delete('/account', async (req, res) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'No token provided' });
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Delete business if owner
    await pool.query('DELETE FROM businesses WHERE owner_id = ?', [decoded.id]);
    // Delete user
    await pool.query('DELETE FROM users WHERE id = ?', [decoded.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
