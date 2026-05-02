async function emitBusinessUpdate({ io, business }) {
  if (!io || !business?.id) return;

  const payload = {
    businessId: business.id,
    ownerId: business.owner_id,
    isActive: business.is_active === 1 || business.is_active === true,
    approvalStatus: business.approval_status,
    business,
    updatedAt: new Date().toISOString(),
  };

  io.emit('business:update', payload);
}

module.exports = {
  emitBusinessUpdate,
};