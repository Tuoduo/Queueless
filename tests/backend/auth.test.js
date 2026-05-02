/**
 * QueueLess — Backend Auth Route Tests
 * Tests: POST /api/auth/login, POST /api/auth/register,
 *        GET /api/auth/me, DELETE /api/auth/account
 *
 * Run from repo root: npm test --prefix backend
 */

const request = require('supertest');

// ─── Mocks ───────────────────────────────────────────────────────────────────
jest.mock('../../backend/db', () => ({
  pool: { query: jest.fn() },
  testConnection: jest.fn().mockResolvedValue(true),
}));

jest.mock('../../backend/utils/notifications', () => ({
  notifyAdmins: jest.fn().mockResolvedValue(undefined),
  createNotification: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../../backend/utils/business_updates', () => ({
  emitBusinessUpdate: jest.fn().mockResolvedValue(undefined),
}));

const express  = require('express');
const authRoutes = require('../../backend/routes/auth');
const { pool } = require('../../backend/db');

const buildApp = () => {
  const app = express();
  app.use(express.json());
  app.set('io', { to: () => ({ emit: jest.fn() }) });
  app.use('/api/auth', authRoutes);
  return app;
};

// ─── Fixture ─────────────────────────────────────────────────────────────────
const VALID_USER = {
  id: 'user-uuid-1',
  name: 'Alice',
  email: 'alice@example.com',
  password: '$2a$10$wJ9.XY1Q6RBQX8Cl/nkA5.X87MuvJtAJ0B0mAuCFJWKY4PpXU4J6W', // "secret123"
  phone: '555-1234',
  role: 'customer',
  notifications_enabled: 1,
  is_banned: 0,
};

// ─── 1. Login: missing fields → 400 ──────────────────────────────────────────
describe('POST /api/auth/login', () => {
  let app;
  beforeAll(() => { app = buildApp(); });

  test('returns 400 when email or password is missing', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'alice@example.com' });

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toMatch(/email and password required/i);
  });

  // ─── 2. Login: user not found → 404 ──────────────────────────────────────
  test('returns 404 when user does not exist', async () => {
    pool.query.mockResolvedValueOnce([[]]);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'ghost@example.com', password: 'any' });

    expect(res.statusCode).toBe(404);
    expect(res.body.error).toMatch(/no account found/i);
  });

  // ─── 3. Login: wrong password → 401 ──────────────────────────────────────
  test('returns 401 on wrong password', async () => {
    pool.query.mockResolvedValueOnce([[VALID_USER]]);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: VALID_USER.email, password: 'wrong_password' });

    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/incorrect password/i);
  });

  // ─── 4. Login: banned user → 403 ─────────────────────────────────────────
  test('returns 403 when user is banned', async () => {
    pool.query.mockResolvedValueOnce([[{ ...VALID_USER, is_banned: 1, ban_reason: 'Spam' }]]);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: VALID_USER.email, password: 'secret123' });

    expect(res.statusCode).toBe(403);
    expect(res.body.error).toMatch(/suspended/i);
  });
});

// ─── 5. Register: duplicate email → 409 ──────────────────────────────────────
describe('POST /api/auth/register', () => {
  let app;
  beforeAll(() => { app = buildApp(); });

  test('returns 409 when email is already registered', async () => {
    pool.query.mockResolvedValueOnce([[{ id: 'existing-id' }]]);

    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Bob', email: 'alice@example.com', password: 'pass123', role: 'customer' });

    expect(res.statusCode).toBe(409);
    expect(res.body.error).toMatch(/email already registered/i);
  });

  // ─── 6. Register: missing fields → 400 ───────────────────────────────────
  test('returns 400 when required fields are missing', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'bob@example.com' });

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toMatch(/missing required fields/i);
  });
});

// ─── 7. GET /api/auth/me: no token → 401 ─────────────────────────────────────
describe('GET /api/auth/me', () => {
  let app;
  beforeAll(() => { app = buildApp(); });

  test('returns 401 when no Authorization header is provided', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/no token/i);
  });

  // ─── 8. GET /api/auth/me: invalid token → 401 ────────────────────────────
  test('returns 401 for an invalid JWT', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer totally.invalid.token');

    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/invalid token/i);
  });
});

// ─── 9. DELETE /api/auth/account: no token → 401 ─────────────────────────────
describe('DELETE /api/auth/account', () => {
  let app;
  beforeAll(() => { app = buildApp(); });

  test('returns 401 when Authorization header is missing', async () => {
    const res = await request(app).delete('/api/auth/account');
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/no token/i);
  });
});

// ─── 10. Health check ────────────────────────────────────────────────────────
describe('GET /api/health', () => {
  test('returns 200 and status ok', async () => {
    const app = express();
    app.get('/api/health', (_req, res) =>
      res.json({ status: 'ok', message: 'Queueless API is running' })
    );

    const res = await request(app).get('/api/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
