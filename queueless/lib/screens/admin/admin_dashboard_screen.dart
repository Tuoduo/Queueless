import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  late final AnimationController _chartController;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _load();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.get('/admin/dashboard');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(result);
        _loading = false;
      });
      _chartController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dashboard_customize_outlined, size: 36, color: AppColors.textHint),
              const SizedBox(height: 12),
              const Text('Dashboard data is unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textHint)),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final userGrowth = List<Map<String, dynamic>>.from(data['userGrowth'] ?? const []);
    final bizGrowth = List<Map<String, dynamic>>.from(data['bizGrowth'] ?? const []);
    final hourlyHeatmap = List<Map<String, dynamic>>.from(data['hourlyHeatmap'] ?? const []);
    final noShowRate = _asDouble(data['noShowRate']);
    final noShowCount = _asInt(data['noShowCount']);
    final resolvedQueueEntries = _asInt(data['resolvedQueueEntries']);
    final categoryPopularity = List<Map<String, dynamic>>.from(data['categoryPopularity'] ?? const []);
    final newUsers30d = userGrowth.fold<int>(0, (sum, point) => sum + _asInt(point['count']));
    final newBusinesses30d = bizGrowth.fold<int>(0, (sum, point) => sum + _asInt(point['count']));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroSection(data, newUsers30d, newBusinesses30d),
          const SizedBox(height: 16),
          _buildMetricWrap(data),
          const SizedBox(height: 20),
          _GrowthChartCard(
            growth: userGrowth,
            animation: _chartController,
            totalUsers: _asInt(data['totalUsers']),
            newUsers30d: newUsers30d,
          ),
          const SizedBox(height: 20),
          _NoShowCard(
            noShowRate: noShowRate,
            noShowCount: noShowCount,
            resolvedQueueEntries: resolvedQueueEntries,
          ),
          const SizedBox(height: 20),
          _HeatmapCard(points: hourlyHeatmap),
          const SizedBox(height: 20),
          _buildCategoryPopularity(categoryPopularity),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Map<String, dynamic> data, int newUsers30d, int newBusinesses30d) {
    final activeQueues = _asInt(data['activeQueues']);
    final openTickets = _asInt(data['openTickets']);
    final pendingBusinesses = _asInt(data['pendingBusinesses']);
    final todayAppointments = _asInt(data['todayAppointments']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1A45), Color(0xFF121A34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'A compact view of growth, operations, and moderation workload.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Network reach', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                      const SizedBox(height: 6),
                      Text(
                        '${_asInt(data['totalUsers'])}',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+$newUsers30d users in the last 30 days',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _HeroStatRow(
                      icon: Icons.storefront_rounded,
                      label: 'New businesses',
                      value: '$newBusinesses30d',
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 10),
                    _HeroStatRow(
                      icon: Icons.schedule_rounded,
                      label: 'Appointments today',
                      value: '$todayAppointments',
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PulseChip(icon: Icons.queue_rounded, label: 'Active queues', value: '$activeQueues', color: AppColors.primary),
              _PulseChip(icon: Icons.support_agent_rounded, label: 'Open tickets', value: '$openTickets', color: AppColors.error),
              _PulseChip(icon: Icons.pending_actions_rounded, label: 'Pending approvals', value: '$pendingBusinesses', color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricWrap(Map<String, dynamic> data) {
    final metrics = <_MetricItem>[
      _MetricItem(Icons.people_rounded, 'Users', '${_asInt(data['totalUsers'])}', AppColors.primary),
      _MetricItem(Icons.store_rounded, 'Businesses', '${_asInt(data['totalBusinesses'])}', AppColors.secondary),
      _MetricItem(Icons.person_rounded, 'Customers', '${_asInt(data['totalCustomers'])}', AppColors.info),
      _MetricItem(Icons.pending_rounded, 'Pending', '${_asInt(data['pendingBusinesses'])}', AppColors.warning),
      _MetricItem(Icons.support_agent_rounded, 'Open Tickets', '${_asInt(data['openTickets'])}', AppColors.error),
      _MetricItem(Icons.block_rounded, 'Banned Users', '${_asInt(data['bannedUsers'])}', AppColors.error),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((metric) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 42) / 2,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(metric.icon, color: metric.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      const SizedBox(height: 4),
                      Text(metric.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryPopularity(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxCount = categories.fold<int>(1, (maxValue, category) => math.max(maxValue, _asInt(category['count'])));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Popularity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Most completed queue and appointment operations across the platform.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          ...categories.take(6).map((category) {
            final name = category['name']?.toString().trim().isNotEmpty == true
                ? category['name'].toString()
                : 'Uncategorized';
            final count = _asInt(category['count']);
            final ratio = count / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('$count', style: const TextStyle(color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: ratio,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricItem(this.icon, this.label, this.value, this.color);
}

class _HeroStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeroStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PulseChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _NoShowCard extends StatelessWidget {
  final double noShowRate;
  final int noShowCount;
  final int resolvedQueueEntries;

  const _NoShowCard({
    required this.noShowRate,
    required this.noShowCount,
    required this.resolvedQueueEntries,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (noShowRate / 100).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No-Show Rate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Cancelled queue entries divided by resolved queue entries in the last 90 days.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${noShowRate.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.warning),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$noShowCount no-shows from $resolvedQueueEntries resolved queue entries',
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                    ),
                    const Icon(Icons.person_off_rounded, color: AppColors.warning),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapCard extends StatefulWidget {
  final List<Map<String, dynamic>> points;

  const _HeatmapCard({required this.points});

  @override
  State<_HeatmapCard> createState() => _HeatmapCardState();
}

class _HeatmapCardState extends State<_HeatmapCard> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  int? _activeWeekday;
  int? _activeHour;

  String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  void _setActiveCell(int weekday, int hour) {
    if (_activeWeekday == weekday && _activeHour == hour) {
      return;
    }
    setState(() {
      _activeWeekday = weekday;
      _activeHour = hour;
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    final dailyTotals = <int, int>{for (var weekday = 0; weekday < 7; weekday += 1) weekday: 0};
    final peakHourByDay = <int, int>{for (var weekday = 0; weekday < 7; weekday += 1) weekday: 0};
    var maxCount = 1;

    for (final point in widget.points) {
      final weekday = int.tryParse(point['weekday']?.toString() ?? '') ?? 0;
      final hour = int.tryParse(point['hour']?.toString() ?? '') ?? 0;
      final count = int.tryParse(point['count']?.toString() ?? '') ?? 0;
      counts['$weekday:$hour'] = count;
      dailyTotals[weekday] = (dailyTotals[weekday] ?? 0) + count;
      final currentPeakHour = peakHourByDay[weekday] ?? 0;
      final currentPeakCount = counts['$weekday:$currentPeakHour'] ?? -1;
      if (count > currentPeakCount) {
        peakHourByDay[weekday] = hour;
      }
      maxCount = math.max(maxCount, count);
    }

    final hasActivity = counts.values.any((count) => count > 0);
    final busiestDay = dailyTotals.entries.reduce((left, right) => left.value >= right.value ? left : right).key;
    final displayWeekday = _activeWeekday ?? busiestDay;
    final displayHour = _activeHour ?? (peakHourByDay[displayWeekday] ?? 0);
    final displayCount = counts['$displayWeekday:$displayHour'] ?? 0;
    final displayDayTotal = dailyTotals[displayWeekday] ?? 0;
    final displayPeakHour = peakHourByDay[displayWeekday] ?? 0;
    final displayPeakCount = counts['$displayWeekday:$displayPeakHour'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Demand Heatmap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Queue joins and appointments by weekday and hour over the last 28 days. Hover a green cell to inspect the combined demand.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.insights_rounded, color: AppColors.success, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActivity ? '${_weekdays[displayWeekday]} · ${_hourLabel(displayHour)}' : 'No activity yet',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasActivity
                            ? '$displayCount queue joins or appointments landed during this hour. $displayDayTotal total demand signals on ${_weekdays[displayWeekday]}. Peak hour: ${_hourLabel(displayPeakHour)} with $displayPeakCount combined visits.'
                            : 'Hover over the grid once activity starts to inspect the hourly demand mix.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Lower', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(width: 8),
              ...List<Widget>.generate(4, (index) {
                final intensity = (index + 1) / 4;
                return Container(
                  width: 18,
                  height: 10,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Color.lerp(const Color(0xFF163020), AppColors.success, intensity) ?? AppColors.success,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
              const SizedBox(width: 4),
              const Text('Higher', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 42),
                    ...List<Widget>.generate(24, (hour) {
                      final label = hour % 6 == 0 ? hour.toString().padLeft(2, '0') : '';
                      return SizedBox(
                        width: 18,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, color: AppColors.textHint),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 6),
                ...List<Widget>.generate(7, (weekday) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 38,
                          child: Text(
                            _weekdays[weekday],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: weekday == displayWeekday ? FontWeight.w700 : FontWeight.w500,
                              color: weekday == displayWeekday ? AppColors.success : AppColors.textHint,
                            ),
                          ),
                        ),
                        ...List<Widget>.generate(24, (hour) {
                          final count = counts['$weekday:$hour'] ?? 0;
                          final intensity = (count / maxCount).clamp(0, 1).toDouble();
                          final isActive = weekday == displayWeekday && hour == displayHour;
                          final dayTotal = dailyTotals[weekday] ?? 0;
                          final peakHour = peakHourByDay[weekday] ?? 0;
                          final peakCount = counts['$weekday:$peakHour'] ?? 0;
                          final fillColor = count == 0
                              ? const Color(0xFF101812)
                              : Color.lerp(const Color(0xFF163020), AppColors.success, intensity) ?? AppColors.success;

                          return MouseRegion(
                            onEnter: (_) => _setActiveCell(weekday, hour),
                            child: GestureDetector(
                              onTap: () => _setActiveCell(weekday, hour),
                              child: Tooltip(
                                waitDuration: const Duration(milliseconds: 120),
                                preferBelow: false,
                                excludeFromSemantics: true,
                                textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(alpha: 0.96),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.28)),
                                ),
                                message: '${_weekdays[weekday]} ${_hourLabel(hour)}\n$count queue joins + appointments in this hour\n$dayTotal total visits across the day\nPeak hour: ${_hourLabel(peakHour)} ($peakCount visits)',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 14,
                                  height: 14,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: fillColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : fillColor.withValues(alpha: count == 0 ? 0.12 : 0.35),
                                    ),
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: AppColors.success.withValues(alpha: 0.28),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartCard extends StatefulWidget {
  final List<Map<String, dynamic>> growth;
  final Animation<double> animation;
  final int totalUsers;
  final int newUsers30d;

  const _GrowthChartCard({
    required this.growth,
    required this.animation,
    required this.totalUsers,
    required this.newUsers30d,
  });

  @override
  State<_GrowthChartCard> createState() => _GrowthChartCardState();
}

class _GrowthChartCardState extends State<_GrowthChartCard> {
  Offset? _pointerPosition;
  int? _activeIndex;

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDay(Map<String, dynamic> point) {
    final raw = point['day']?.toString() ?? '';
    return DateTime.tryParse(raw);
  }

  void _updatePointer(Offset localPosition, double width) {
    if (widget.growth.isEmpty || width <= 0) return;
    final stepX = widget.growth.length == 1 ? width : width / (widget.growth.length - 1);
    final hoveredIndex = (localPosition.dx / stepX).round().clamp(0, widget.growth.length - 1);
    setState(() {
      _pointerPosition = localPosition;
      _activeIndex = hoveredIndex;
    });
  }

  void _clearPointer() {
    if (_pointerPosition == null && _activeIndex == null) return;
    setState(() {
      _pointerPosition = null;
      _activeIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = widget.growth.map((point) => _asInt(point['count'])).toList();
    final maxCount = counts.fold<int>(1, (maxValue, count) => math.max(maxValue, count));
    final highestCount = counts.fold<int>(0, math.max);
    final averageDaily = widget.growth.isEmpty ? '0.0' : (widget.newUsers30d / widget.growth.length).toStringAsFixed(1);
    final firstDate = widget.growth.isNotEmpty ? _parseDay(widget.growth.first) : null;
    final midDate = widget.growth.length > 15 ? _parseDay(widget.growth[14]) : null;
    final lastDate = widget.growth.isNotEmpty ? _parseDay(widget.growth.last) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('User Growth', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Daily user signups over the last 30 days. Hover or drag across the line for exact counts.',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+${widget.newUsers30d}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
                    const Text('last 30 days', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ChartMetaChip(label: 'Total users', value: '${widget.totalUsers}', color: AppColors.secondary),
              const SizedBox(width: 8),
              _ChartMetaChip(label: 'Best day', value: '$highestCount', color: AppColors.warning),
              const SizedBox(width: 8),
              _ChartMetaChip(label: 'Daily avg', value: averageDaily, color: AppColors.info),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                return MouseRegion(
                  onHover: (event) => _updatePointer(event.localPosition, chartWidth),
                  onExit: (_) => _clearPointer(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _updatePointer(details.localPosition, chartWidth),
                    onPanStart: (details) => _updatePointer(details.localPosition, chartWidth),
                    onPanUpdate: (details) => _updatePointer(details.localPosition, chartWidth),
                    onPanEnd: (_) => _clearPointer(),
                    onTapCancel: _clearPointer,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedBuilder(
                          animation: widget.animation,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(chartWidth, 220),
                              painter: _GrowthChartPainter(
                                counts: counts,
                                maxCount: maxCount,
                                progress: Curves.easeOutCubic.transform(widget.animation.value),
                                activeIndex: _activeIndex,
                              ),
                            );
                          },
                        ),
                        if (counts.every((count) => count == 0))
                          const Center(
                            child: Text(
                              'No user signups recorded in this period',
                              style: TextStyle(fontSize: 12, color: AppColors.textHint),
                            ),
                          ),
                        if (_activeIndex != null && _pointerPosition != null && widget.growth.isNotEmpty)
                          Positioned(
                            left: math.min(_pointerPosition!.dx + 12, math.max(0.0, chartWidth - 166)),
                            top: math.max(10, _pointerPosition!.dy - 78),
                            child: _GrowthTooltip(
                              dateLabel: DateFormat('dd MMM yyyy').format(_parseDay(widget.growth[_activeIndex!]) ?? DateTime.now()),
                              count: _asInt(widget.growth[_activeIndex!]['count']),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(firstDate != null ? DateFormat('dd MMM').format(firstDate) : '', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              Text(midDate != null ? DateFormat('dd MMM').format(midDate) : '', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              Text(lastDate != null ? DateFormat('dd MMM').format(lastDate) : '', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartMetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ChartMetaChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _GrowthTooltip extends StatelessWidget {
  final String dateLabel;
  final int count;

  const _GrowthTooltip({required this.dateLabel, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 162,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '$count new users',
            style: const TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  final List<int> counts;
  final int maxCount;
  final double progress;
  final int? activeIndex;

  _GrowthChartPainter({
    required this.counts,
    required this.maxCount,
    required this.progress,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    if (counts.isEmpty) return;

    final stepX = counts.length == 1 ? width : width / (counts.length - 1);

    if (activeIndex != null) {
      final guideX = stepX * activeIndex!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(math.max(0, guideX - 16), 0, math.min(width, guideX + 16), height),
          const Radius.circular(12),
        ),
        Paint()..color = AppColors.primary.withValues(alpha: 0.08),
      );
      canvas.drawLine(
        Offset(guideX, 0),
        Offset(guideX, height),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.35)
          ..strokeWidth = 1.2,
      );
    }

    final gridPaint = Paint()
      ..color = AppColors.glassBorder
      ..strokeWidth = 0.5;
    for (var index = 0; index <= 4; index++) {
      final y = height * index / 4;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    if (counts.every((count) => count == 0)) {
      return;
    }

    final points = <Offset>[];
    for (var index = 0; index < counts.length; index++) {
      final x = stepX * index;
      final ratio = counts[index] / maxCount;
      final y = height - (ratio * height * 0.82 * progress) - (height * 0.10);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(0, height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(width, height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.secondary.withValues(alpha: 0.26 * progress),
            AppColors.secondary.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height)),
    );

    final linePaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final controlPoint = previous.dx + ((current.dx - previous.dx) / 2);
      linePath.cubicTo(controlPoint, previous.dy, controlPoint, current.dy, current.dx, current.dy);
    }
    canvas.drawPath(linePath, linePaint);

    final peak = counts.reduce(math.max);
    for (var index = 0; index < counts.length; index++) {
      if (counts[index] == peak && peak > 0) {
        canvas.drawCircle(points[index], 5 * progress, Paint()..color = AppColors.warning);
        canvas.drawCircle(points[index], 3 * progress, Paint()..color = Colors.white);
      }
      if (activeIndex == index) {
        canvas.drawCircle(points[index], 5, Paint()..color = AppColors.secondary);
        canvas.drawCircle(points[index], 2.6, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.counts != counts;
  }
}