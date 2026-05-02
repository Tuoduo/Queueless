/**
 * QueueLess — Backend Queue Route Tests
 * Tests the POST /api/queues/:businessId/join-guest endpoint
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
  createNotification: jest.fn().mockResolvedValue(undefined),
  createNotifications: jest.fn().mockResolvedValue(undefined),
  notifyAdmins: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../../backend/utils/business_updates', () => ({
  emitBusinessUpdate: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../../backend/utils/eta', () => ({
  buildEtaConfig: jest.fn().mockReturnValue({}),
  estimateQueueWaitRange: jest.fn().mockReturnValue({ minMinutes: 5, maxMinutes: 10 }),
  formatEtaRangeLabel: jest.fn().mockReturnValue('5–10 min'),
}));

const express     = require('express');
const queueRoutes = require('../../backend/routes/queues');
const { pool }    = require('../../backend/db');

const buildApp = () => {
  const app = express();
  app.use(express.json());
  app.set('io', { to: () => ({ emit: jest.fn() }) });
  app.use('/api/queues', queueRoutes);
  return app;
};

// ─── Fixtures ────────────────────────────────────────────────────────────────
const ACTIVE_BUSINESS = {
  id: 'biz-1',
  name: 'Baklava House',
  service_type: 'queue',
  is_active: 1,
};

// ─── Tests ───────────────────────────────────────────────────────────────────
describe('POST /api/queues/:businessId/join-guest', () => {
  let app;
  beforeEach(() => {
    app = buildApp();
    jest.clearAllMocks();
  });

  // ── 1. Missing guest_name → 400 ────────────────────────────────────────────
  test('returns 400 when guest_name is missing', async () => {
    const res = await request(app)
      .post('/api/queues/biz-1/join-guest')
      .send({ product_name: 'Baklava' });

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toMatch(/guest_name required/i);
  });

  // ── 2. Business not found → 404 ────────────────────────────────────────────
  test('returns 404 when business does not exist', async () => {
    pool.query.mockResolvedValueOnce([[]]);

    const res = await request(app)
      .post('/api/queues/unknown-biz/join-guest')
      .send({ guest_name: 'Alice' });

    expect(res.statusCode).toBe(404);
    expect(res.body.error).toMatch(/business not found/i);
  });

  // ── 3. Business closed → 403 ───────────────────────────────────────────────
  test('returns 403 when business is not active', async () => {
    pool.query.mockResolvedValueOnce([[{ ...ACTIVE_BUSINESS, is_active: 0 }]]);

    const res = await request(app)
      .post('/api/queues/biz-1/join-guest')
      .send({ guest_name: 'Bob' });

    expect(res.statusCode).toBe(403);
    expect(res.body.error).toMatch(/closed/i);
  });

  // ── 4. Queue paused → 403 ──────────────────────────────────────────────────
  test('returns 403 when queue is paused', async () => {
    pool.query
      .mockResolvedValueOnce([[ACTIVE_BUSINESS]])
      .mockResolvedValueOnce([[{ is_paused: 1 }]]);

    const res = await request(app)
      .post('/api/queues/biz-1/join-guest')
      .send({ guest_name: 'Charlie' });

    expect(res.statusCode).toBe(403);
    expect(res.body.error).toMatch(/paused/i);
  });

  // ── 5. Successful join (no products) → 201 ─────────────────────────────────
  test('returns 201 and entry data on successful guest join', async () => {
    pool.query
      .mockResolvedValueOnce([[ACTIVE_BUSINESS]])
      .mockResolvedValueOnce([[{ is_paused: 0 }]])
      .mockResolvedValueOnce([[{ cnt: 2 }]])
      .mockResolvedValueOnce([{ insertId: 1 }])
      .mockResolvedValueOnce([{ insertId: 1 }])
      .mockResolvedValueOnce([{ insertId: 1 }])
      .mockResolvedValueOnce([[{
        id: 'entry-uuid',
        business_id: 'biz-1',
        customer_name: 'Dave',
        position: 3,
        status: 'waiting',
        total_price: 0,
      }]])
      .mockResolvedValueOnce([[{ cnt: 3 }]])
      .mockResolvedValueOnce([[{ owner_id: 'owner-1', name: 'Baklava House' }]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[]])
      .mockResolvedValueOnce([[{ avg_sec: 300 }]]);

    const res = await request(app)
      .post('/api/queues/biz-1/join-guest')
      .send({ guest_name: 'Dave', payment_method: 'later' });

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.position).toBe(3);
    expect(res.body.entry).toBeDefined();
  });
});
