const jwt = require('jsonwebtoken');
require('dotenv').config();

function authenticate(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'Authorization header missing' });

  const token = authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token missing' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function authorizeOwner(req, res, next) {
  if (req.user?.role !== 'businessOwner') {
    return res.status(403).json({ error: 'Business owner access required' });
  }
  next();
}

module.exports = { authenticate, authorizeOwner };
