const { v4: uuidv4 } = require('uuid');

function toJsonString(value) {
  if (value == null) return null;
  try {
    return JSON.stringify(value);
  } catch (_) {
    return null;
  }
}

function parseMetadata(value) {
  if (value == null) return null;
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch (_) {
      return null;
    }
  }
  if (typeof value === 'object') {
    return value;
  }
  return null;
}

function mapNotificationRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    recipient_id: row.recipient_id,
    title: row.title,
    body: row.body,
    type: row.type,
    entity_type: row.entity_type,
    entity_id: row.entity_id,
    is_read: row.is_read === 1 || row.is_read === true,
    metadata: parseMetadata(row.metadata),
    created_at: row.created_at,
  };
}

async function createNotification({ pool, io, userId, title, body, type = 'general', entityType = null, entityId = null, metadata = null }) {
  if (!pool || !io || !userId || !title || !body) return null;

  const [userRows] = await pool.query('SELECT notifications_enabled FROM users WHERE id = ?', [userId]);
  if (userRows.length === 0) return null;
  if (userRows[0].notifications_enabled === 0 || userRows[0].notifications_enabled === false) {
    return null;
  }

  const id = uuidv4();
  await pool.query(
    `INSERT INTO notifications (id, recipient_id, title, body, type, entity_type, entity_id, metadata)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [id, userId, title, body, type, entityType, entityId, toJsonString(metadata)]
  );

  const [rows] = await pool.query('SELECT * FROM notifications WHERE id = ?', [id]);
  const notification = mapNotificationRow(rows[0]);
  io.to(`user:${userId}`).emit('notification:new', notification);
  return notification;
}

async function createNotifications({ pool, io, userIds, title, body, type = 'general', entityType = null, entityId = null, metadata = null }) {
  if (!Array.isArray(userIds) || userIds.length === 0) return [];

  const uniqueIds = [...new Set(userIds.map((id) => String(id || '').trim()).filter(Boolean))];
  const created = [];
  for (const userId of uniqueIds) {
    const notification = await createNotification({
      pool,
      io,
      userId,
      title,
      body,
      type,
      entityType,
      entityId,
      metadata,
    });
    if (notification) {
      created.push(notification);
    }
  }
  return created;
}

async function notifyAdmins({ pool, io, title, body, type = 'admin', entityType = null, entityId = null, metadata = null }) {
  if (!pool || !io || !title || !body) return [];
  const [adminRows] = await pool.query("SELECT id FROM users WHERE role = 'admin'");
  const adminIds = adminRows.map((row) => row.id);
  return createNotifications({ pool, io, userIds: adminIds, title, body, type, entityType, entityId, metadata });
}

module.exports = {
  createNotification,
  createNotifications,
  notifyAdmins,
  mapNotificationRow,
};