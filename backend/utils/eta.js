function clampNumber(value, fallback, min, max) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function roundMinutes(value) {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.max(1, Math.round(value));
}

function buildEtaConfig(avgServiceSeconds) {
  const avgMinutes = clampNumber(Number(avgServiceSeconds) / 60, 8, 2, 180);
  const prepMinutes = clampNumber(avgMinutes * 0.32, 2, 1, 24);
  const unitMinutes = clampNumber(avgMinutes - prepMinutes, 4, 1, 120);

  return {
    prepMinutes,
    unitMinutes,
    sigma: 0.42,
  };
}

function dampedWorkload(unitCount, sigma) {
  let total = 0;
  for (let index = 1; index <= unitCount; index += 1) {
    total += 1 / Math.pow(index, sigma);
  }
  return total;
}

function equivalentUnits({ itemCount, durationMinutes }, config = buildEtaConfig()) {
  const directCount = Number(itemCount);
  if (Number.isFinite(directCount) && directCount > 0) {
    return Math.max(1, Math.round(directCount));
  }

  const duration = Number(durationMinutes);
  if (Number.isFinite(duration) && duration > 0) {
    return Math.max(1, Math.round(duration / Math.max(config.unitMinutes, 1)));
  }

  return 1;
}

function estimateServiceRange(unitCount, config = buildEtaConfig()) {
  const safeUnits = Math.max(1, Math.round(Number(unitCount) || 1));
  const sigma = clampNumber(config.sigma, 0.42, 0.05, 0.95);
  const prepMinutes = clampNumber(config.prepMinutes, 2, 1, 24);
  const unitMinutes = clampNumber(config.unitMinutes, 4, 1, 120);
  const fasterSigma = Math.min(0.95, sigma + 0.12);
  const slowerSigma = Math.max(0.05, sigma - 0.10);
  const contextBuffer = Math.max(1, Math.round(prepMinutes * 0.25));

  const minMinutes = roundMinutes(prepMinutes + (unitMinutes * dampedWorkload(safeUnits, fasterSigma)));
  const maxMinutes = Math.max(
    minMinutes,
    roundMinutes(prepMinutes + (unitMinutes * dampedWorkload(safeUnits, slowerSigma)) + contextBuffer)
  );

  return { minMinutes, maxMinutes };
}

function estimateQueueWaitRange(entriesAhead, config = buildEtaConfig()) {
  const rows = Array.isArray(entriesAhead) ? entriesAhead : [];
  if (rows.length === 0) {
    return { minMinutes: 0, maxMinutes: 0 };
  }

  return rows.reduce(
    (range, row) => {
      const units = equivalentUnits(
        {
          itemCount: row?.item_count,
          durationMinutes: row?.product_duration_minutes,
        },
        config
      );
      const serviceRange = estimateServiceRange(units, config);
      return {
        minMinutes: range.minMinutes + serviceRange.minMinutes,
        maxMinutes: range.maxMinutes + serviceRange.maxMinutes,
      };
    },
    { minMinutes: 0, maxMinutes: 0 }
  );
}

function formatEtaRangeLabel(minMinutes, maxMinutes) {
  const min = Math.max(0, Math.round(Number(minMinutes) || 0));
  const max = Math.max(min, Math.round(Number(maxMinutes) || 0));

  if (max <= 0) return '<1 min';
  if (min <= 0) return `1 - ${max} min`;
  if (min === max) return `${min} min`;
  return `${min} - ${max} min`;
}

module.exports = {
  buildEtaConfig,
  equivalentUnits,
  estimateServiceRange,
  estimateQueueWaitRange,
  formatEtaRangeLabel,
};