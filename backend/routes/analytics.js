const express = require('express');
const { pool } = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

function startOfUtcDay(value = new Date()) {
  const date = new Date(value);
  date.setUTCHours(0, 0, 0, 0);
  return date;
}

function startOfUtcMonth(value = new Date()) {
  const date = value instanceof Date ? new Date(value) : new Date(`${value}-01T00:00:00.000Z`);
  date.setUTCDate(1);
  date.setUTCHours(0, 0, 0, 0);
  return date;
}

function formatDay(value) {
  return startOfUtcDay(value).toISOString().slice(0, 10);
}

function formatMonth(value) {
  return startOfUtcMonth(value).toISOString().slice(0, 7);
}

function parseDay(value, fallback, minDay, maxDay) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return formatDay(fallback);
  }

  const parsed = startOfUtcDay(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) {
    return formatDay(fallback);
  }
  if (parsed < minDay || parsed > maxDay) {
    return formatDay(fallback);
  }
  return formatDay(parsed);
}

function getDateSeries(endDay, length) {
  const end = startOfUtcDay(`${endDay}T00:00:00.000Z`);
  return Array.from({ length }, (_, index) => {
    const date = new Date(end);
    date.setUTCDate(end.getUTCDate() - (length - 1 - index));
    return formatDay(date);
  });
}

function parseMonth(value, fallback, minMonth, maxMonth) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}$/.test(value)) {
    return formatMonth(fallback);
  }

  const parsed = startOfUtcMonth(value);
  if (Number.isNaN(parsed.getTime())) {
    return formatMonth(fallback);
  }
  if (parsed < minMonth || parsed > maxMonth) {
    return formatMonth(fallback);
  }
  return formatMonth(parsed);
}

async function getEarliestSelectableMonth(businessId, fallbackMonth) {
  const [rows] = await pool.query(
    `SELECT MIN(source_date) as first_date
     FROM (
       SELECT MIN(joined_at) as source_date FROM queue_entries WHERE business_id = ?
       UNION ALL
       SELECT MIN(date_time) as source_date FROM appointments WHERE business_id = ?
       UNION ALL
       SELECT MIN(created_at) as source_date FROM businesses WHERE id = ?
     ) sources`,
    [businessId, businessId, businessId]
  );

  const firstDate = rows[0]?.first_date;
  if (!firstDate) {
    return formatMonth(fallbackMonth);
  }

  return formatMonth(firstDate instanceof Date ? firstDate : new Date(firstDate));
}

function getMonthSeries(endMonth, length) {
  const end = startOfUtcMonth(endMonth);
  return Array.from({ length }, (_, index) => {
    const date = new Date(end);
    date.setUTCMonth(end.getUTCMonth() - (length - 1 - index));
    return formatMonth(date);
  });
}

// GET /api/analytics/:businessId
router.get('/:businessId', authenticate, async (req, res) => {
  const { businessId } = req.params;
  try {
    // Verify ownership
    const [biz] = await pool.query('SELECT owner_id, total_customers_served, name FROM businesses WHERE id = ?', [businessId]);
    if (biz.length === 0) return res.status(404).json({ error: 'Business not found' });
    if (biz[0].owner_id !== req.user.id) return res.status(403).json({ error: 'Forbidden' });

    // Total customers served (all time)
    const totalServed = biz[0].total_customers_served || 0;
    const today = startOfUtcDay();
    const minSelectableDay = new Date(today);
    minSelectableDay.setUTCDate(today.getUTCDate() - 364);
    const currentMonth = startOfUtcMonth(today);
    const minSelectableMonth = startOfUtcMonth(await getEarliestSelectableMonth(businessId, currentMonth));

    const selectedTrafficDay = parseDay(req.query.day, today, minSelectableDay, today);
    const selectedProfitMonth = parseMonth(req.query.profitMonth, currentMonth, minSelectableMonth, currentMonth);
    const trafficDays = getDateSeries(selectedTrafficDay, 7);
    const trafficStartDay = trafficDays[0];
    const profitMonths = getMonthSeries(selectedProfitMonth, 12);
    const profitStartMonth = profitMonths[0];

    // Average service time (last 30 days). Fall back to configured item durations so queue analytics never degrades to N/A.
    const [avgTime] = await pool.query(
      `SELECT
         ROUND(
           COALESCE(
             AVG(CASE WHEN status = 'done' AND service_duration_seconds IS NOT NULL THEN service_duration_seconds END),
             AVG(CASE WHEN status IN ('waiting','serving','done') AND product_duration_minutes > 0 THEN product_duration_minutes * 60 END),
             300
           )
         ) as avg_sec,
         SUM(CASE WHEN status = 'done' AND service_duration_seconds IS NOT NULL THEN 1 ELSE 0 END) as completed_count
       FROM queue_entries
       WHERE business_id = ?
         AND (
           completed_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
           OR joined_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
         )`,
      [businessId]
    );

    // Peak hours for the selected day, combining queue joins and appointments.
    const [hourly] = await pool.query(
      `SELECT hour, SUM(count) as count
       FROM (
         SELECT HOUR(joined_at) as hour, COUNT(*) as count
         FROM queue_entries
         WHERE business_id = ? AND DATE(joined_at) = ?
         GROUP BY HOUR(joined_at)

         UNION ALL

         SELECT HOUR(date_time) as hour, COUNT(*) as count
         FROM appointments
         WHERE business_id = ? AND DATE(date_time) = ? AND status != 'cancelled'
         GROUP BY HOUR(date_time)
       ) traffic
       GROUP BY hour
       ORDER BY hour ASC`,
      [businessId, selectedTrafficDay, businessId, selectedTrafficDay]
    );

    // Daily traffic totals for the selected 7-day window.
    const [dailyTraffic] = await pool.query(
      `SELECT day, SUM(count) as count
       FROM (
         SELECT DATE(joined_at) as day, COUNT(*) as count
         FROM queue_entries
         WHERE business_id = ? AND DATE(joined_at) BETWEEN ? AND ?
         GROUP BY DATE(joined_at)

         UNION ALL

         SELECT DATE(date_time) as day, COUNT(*) as count
         FROM appointments
         WHERE business_id = ? AND DATE(date_time) BETWEEN ? AND ? AND status != 'cancelled'
         GROUP BY DATE(date_time)
       ) traffic
       GROUP BY day
       ORDER BY day ASC`,
      [businessId, trafficStartDay, selectedTrafficDay, businessId, trafficStartDay, selectedTrafficDay]
    );

    const trafficByDay = new Map(
      dailyTraffic.map((row) => [
        row.day instanceof Date ? row.day.toISOString().slice(0, 10) : String(row.day).slice(0, 10),
        parseInt(row.count, 10) || 0,
      ])
    );

    // Active queue now
    const [activeQueue] = await pool.query(
      "SELECT SUM(CASE WHEN status='waiting' THEN 1 ELSE 0 END) as waiting, SUM(CASE WHEN status='serving' THEN 1 ELSE 0 END) as serving FROM queue_entries WHERE business_id = ? AND status IN ('waiting','serving')",
      [businessId]
    );

    // Total appointments this month
    const [monthlyAppt] = await pool.query(
      `SELECT COUNT(*) as count FROM appointments
       WHERE business_id = ? AND MONTH(created_at) = MONTH(NOW()) AND YEAR(created_at) = YEAR(NOW()) AND status != 'cancelled'`,
      [businessId]
    );

    // Completed appointments last 30 days
    const [completedAppt] = await pool.query(
      `SELECT COUNT(*) as count FROM appointments
       WHERE business_id = ? AND status = 'completed' AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)`,
      [businessId]
    );

    // Today's total revenue (queue + appointments)
    const [todayQueueRev] = await pool.query(
      `SELECT COALESCE(SUM(total_price), 0) as revenue FROM queue_entries
       WHERE business_id = ? AND DATE(joined_at) = CURDATE() AND status IN ('waiting','serving','done')`,
      [businessId]
    );
    const [todayApptRev] = await pool.query(
      `SELECT COALESCE(SUM(final_price), 0) as revenue FROM appointments
       WHERE business_id = ? AND DATE(date_time) = CURDATE() AND status != 'cancelled'`,
      [businessId]
    );
    const todayRevenue = parseFloat(todayQueueRev[0].revenue || 0) + parseFloat(todayApptRev[0].revenue || 0);

    // Today's total cost - sum of stored total_cost from queue entries
    const [todayQueueCost] = await pool.query(
      `SELECT COALESCE(SUM(total_cost), 0) as total_cost
       FROM queue_entries
       WHERE business_id = ? AND DATE(joined_at) = CURDATE() AND status IN ('waiting','serving','done')`,
      [businessId]
    );
    const todayCost = parseFloat(todayQueueCost[0]?.total_cost || 0);
    const todayNet = todayRevenue - todayCost;

    const [profitRows] = await pool.query(
      `SELECT
         month_key,
         SUM(revenue) as revenue,
         SUM(cost) as cost,
         SUM(customers) as customers
       FROM (
         SELECT DATE_FORMAT(joined_at, '%Y-%m') as month_key,
                COALESCE(SUM(total_price), 0) as revenue,
                COALESCE(SUM(total_cost), 0) as cost,
                COUNT(*) as customers
         FROM queue_entries
         WHERE business_id = ?
           AND DATE_FORMAT(joined_at, '%Y-%m') BETWEEN ? AND ?
           AND status IN ('waiting','serving','done')
         GROUP BY DATE_FORMAT(joined_at, '%Y-%m')

         UNION ALL

         SELECT DATE_FORMAT(date_time, '%Y-%m') as month_key,
                COALESCE(SUM(final_price), 0) as revenue,
                0 as cost,
                COUNT(*) as customers
         FROM appointments
         WHERE business_id = ?
           AND DATE_FORMAT(date_time, '%Y-%m') BETWEEN ? AND ?
           AND status != 'cancelled'
         GROUP BY DATE_FORMAT(date_time, '%Y-%m')
       ) financials
       GROUP BY month_key
       ORDER BY month_key ASC`,
      [businessId, profitStartMonth, selectedProfitMonth, businessId, profitStartMonth, selectedProfitMonth]
    );

    const profitByMonth = new Map(
      profitRows.map((row) => {
        const month = String(row.month_key).slice(0, 7);
        const revenue = parseFloat(row.revenue || 0);
        const cost = parseFloat(row.cost || 0);
        const customers = parseInt(row.customers, 10) || 0;
        return [
          month,
          {
            revenue,
            cost,
            netProfit: revenue - cost,
            customers,
          },
        ];
      })
    );

    const profitChart = profitMonths.map((month) => {
      const point = profitByMonth.get(month) || { revenue: 0, cost: 0, netProfit: 0, customers: 0 };
      return {
        month,
        revenue: parseFloat(point.revenue.toFixed(2)),
        cost: parseFloat(point.cost.toFixed(2)),
        netProfit: parseFloat(point.netProfit.toFixed(2)),
        customers: point.customers,
      };
    });

    const profitSummary = profitChart.reduce(
      (summary, point) => ({
        revenue: summary.revenue + point.revenue,
        cost: summary.cost + point.cost,
        netProfit: summary.netProfit + point.netProfit,
        customers: summary.customers + point.customers,
      }),
      { revenue: 0, cost: 0, netProfit: 0, customers: 0 }
    );

    res.json({
      businessName: biz[0].name,
      totalServed,
      avgServiceSeconds: Math.max(60, Math.round(parseFloat(avgTime[0]?.avg_sec || 300))),
      completedQueueCount: parseInt(avgTime[0]?.completed_count, 10) || 0,
      peakHours: hourly.map((row) => ({
        hour: parseInt(row.hour, 10) || 0,
        count: parseInt(row.count, 10) || 0,
      })),
      hourlyTraffic: hourly.map((row) => ({
        hour: parseInt(row.hour, 10) || 0,
        count: parseInt(row.count, 10) || 0,
      })),
      trafficDays: trafficDays.map((day) => ({ day, count: trafficByDay.get(day) || 0 })),
      selectedTrafficDay,
      selectedProfitMonth,
      earliestProfitMonth: formatMonth(minSelectableMonth),
      dailyQueueStats: trafficDays.map((day) => ({ day, count: trafficByDay.get(day) || 0 })),
      dailyApptStats: [],
      activeWaiting: parseInt(activeQueue[0]?.waiting) || 0,
      activeServing: parseInt(activeQueue[0]?.serving) || 0,
      monthlyAppointments: monthlyAppt[0]?.count || 0,
      completedAppointments: completedAppt[0]?.count || 0,
      todayRevenue: parseFloat(todayRevenue.toFixed(2)),
      todayCost: parseFloat(todayCost.toFixed(2)),
      todayNet: parseFloat(todayNet.toFixed(2)),
      profitChart,
      profitSummary: {
        revenue: parseFloat(profitSummary.revenue.toFixed(2)),
        cost: parseFloat(profitSummary.cost.toFixed(2)),
        netProfit: parseFloat(profitSummary.netProfit.toFixed(2)),
        customers: profitSummary.customers,
      },
      monthlyChart: profitChart,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
