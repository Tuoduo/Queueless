import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String? _selectedTrafficDay;
  String? _selectedProfitMonth;
  late AnimationController _chartController;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _load({String? trafficDay, String? profitMonth}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final ownerId = auth.currentUser?.id ?? '';

      var business = businessProvider.getBusinessByOwnerId(ownerId);
      if (business == null && ownerId.isNotEmpty) {
        await businessProvider.loadOwnerBusiness(ownerId);
        business = businessProvider.getBusinessByOwnerId(ownerId);
      }

      if (business == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Business not found';
          _loading = false;
        });
        return;
      }

      final query = <String, String>{
        if ((trafficDay ?? _selectedTrafficDay)?.isNotEmpty == true) 'day': trafficDay ?? _selectedTrafficDay!,
        if ((profitMonth ?? _selectedProfitMonth)?.isNotEmpty == true) 'profitMonth': profitMonth ?? _selectedProfitMonth!,
      };
      final queryString = query.isEmpty
          ? ''
          : '?${query.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';

      final result = await ApiService.get('/analytics/${business.id}$queryString');

      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
        _selectedTrafficDay = result['selectedTrafficDay']?.toString();
        _selectedProfitMonth = result['selectedProfitMonth']?.toString();
      });
      _chartController.forward(from: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickDay({
    required String? currentDay,
    required ValueChanged<String> onSelected,
  }) async {
    final now = DateTime.now();
    final initialDate = _tryParseDay(currentDay) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 364)),
      lastDate: DateTime(now.year, now.month, now.day),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Select a date',
    );

    if (picked == null || !mounted) return;
    onSelected(DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickProfitMonth() async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final firstMonth = _tryParseMonth(_data?['earliestProfitMonth']?.toString()) ?? DateTime(now.year, now.month - 11);
    final initialMonth = _tryParseMonth(_selectedProfitMonth) ?? currentMonth;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(
        initialMonth: initialMonth,
        firstMonth: firstMonth,
        lastMonth: currentMonth,
      ),
    );

    if (picked == null || !mounted) return;
    await _load(profitMonth: DateFormat('yyyy-MM').format(picked));
  }

  String _formatDayLabel(String rawDay, {bool compact = false}) {
    try {
      final date = DateTime.parse(rawDay);
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final pattern = compact ? 'EEE, d MMM' : 'd MMM, EEEE';
      final formatted = DateFormat(pattern).format(date);
      if (isToday) {
        return compact ? 'Today' : '$formatted (Today)';
      }
      return formatted;
    } catch (_) {
      return rawDay;
    }
  }

  String _formatMonthLabel(String rawMonth, {bool compact = false}) {
    try {
      final date = DateTime.parse('$rawMonth-01');
      return DateFormat(compact ? 'MMM yyyy' : 'MMMM yyyy').format(date);
    } catch (_) {
      return rawMonth;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.textHint)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final data = _data ?? <String, dynamic>{};
    final hourlyTraffic = List<Map<String, dynamic>>.from(data['hourlyTraffic'] ?? data['peakHours'] ?? const []);
    final trafficDays = List<Map<String, dynamic>>.from(data['trafficDays'] ?? const []);
    final avgSeconds = _asIntValue(data['avgServiceSeconds'], 300);
    final avgMin = math.max(1, (avgSeconds / 60).round());
    final totalServed = _asIntValue(data['totalServed']);
    final activeWaiting = _asIntValue(data['activeWaiting']);
    final activeServing = _asIntValue(data['activeServing']);
    final monthlyAppointments = _asIntValue(data['monthlyAppointments']);
    final todayRevenue = _asDoubleValue(data['todayRevenue']);
    final todayCost = _asDoubleValue(data['todayCost']);
    final todayNet = _asDoubleValue(data['todayNet']);
    final profitChart = List<Map<String, dynamic>>.from(data['profitChart'] ?? data['monthlyChart'] ?? const []);
    final profitSummary = Map<String, dynamic>.from(data['profitSummary'] ?? const {});
    final profitWindowNet = _asDoubleValue(profitSummary['netProfit']);
    final profitWindowCustomers = _asIntValue(profitSummary['customers']);
    final sevenDayCustomers = trafficDays.fold<int>(
      0,
      (sum, day) => sum + _asIntValue(day['count']),
    );
    final selectedTrafficDay = _selectedTrafficDay ?? data['selectedTrafficDay']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final selectedProfitMonth = _selectedProfitMonth ?? data['selectedProfitMonth']?.toString() ?? DateFormat('yyyy-MM').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: () => _load(trafficDay: _selectedTrafficDay, profitMonth: _selectedProfitMonth),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: "Today's Earnings", icon: Icons.attach_money_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Revenue',
                  value: _formatCurrency(todayRevenue),
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.trending_down_rounded,
                  label: 'Cost',
                  value: _formatCurrency(todayCost),
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: todayNet >= 0
                    ? AppColors.primaryGradient
                    : const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF7043)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    todayNet >= 0 ? Icons.emoji_events_rounded : Icons.warning_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Net Profit', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        _formatCurrency(todayNet),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Queue Stats', icon: Icons.people_outline_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Total Served',
                  value: '$totalServed',
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.timer_outlined,
                  label: 'Avg. Time',
                  value: '$avgMin min',
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.people_outline_rounded,
                  label: 'Waiting',
                  value: '$activeWaiting',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.calendar_today_outlined,
                  label: 'Appts (Month)',
                  value: '$monthlyAppointments',
                  color: AppColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (activeServing > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.servingGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      '$activeServing customer(s) being served now',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            _SectionTitle(title: 'Traffic by Hour', icon: Icons.query_stats_rounded),
            const SizedBox(height: 12),
            _TrafficChartCard(
              hourlyTraffic: hourlyTraffic,
              trafficDays: trafficDays,
              selectedDay: selectedTrafficDay,
              animation: _chartController,
              formatDayLabel: _formatDayLabel,
              onPickDay: () => _pickDay(
                currentDay: selectedTrafficDay,
                onSelected: (day) => _load(trafficDay: day),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Net Profit', icon: Icons.show_chart_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.savings_outlined,
                  label: '12 Month Net Profit',
                  value: _formatCurrency(profitWindowNet),
                  color: profitWindowNet >= 0 ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.groups_rounded,
                  label: '12 Month Customers',
                  value: '$profitWindowCustomers',
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NetProfitChartCard(
              profitChart: profitChart,
              selectedMonth: selectedProfitMonth,
              animation: _chartController,
              formatMonthLabel: _formatMonthLabel,
              onPickMonth: _pickProfitMonth,
            ),
            const SizedBox(height: 12),
            Text(
              '$sevenDayCustomers customers in the selected 7-day traffic window.',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrafficChartCard extends StatefulWidget {
  final List<Map<String, dynamic>> hourlyTraffic;
  final List<Map<String, dynamic>> trafficDays;
  final String selectedDay;
  final Animation<double> animation;
  final String Function(String rawDay, {bool compact}) formatDayLabel;
  final VoidCallback onPickDay;

  const _TrafficChartCard({
    required this.hourlyTraffic,
    required this.trafficDays,
    required this.selectedDay,
    required this.animation,
    required this.formatDayLabel,
    required this.onPickDay,
  });

  @override
  State<_TrafficChartCard> createState() => _TrafficChartCardState();
}

class _TrafficChartCardState extends State<_TrafficChartCard> {
  Offset? _pointerPosition;
  int? _activeWindowStart;

  List<int> get _counts {
    final hourMap = <int, int>{};
    for (final point in widget.hourlyTraffic) {
      final hour = _asIntValue(point['hour']);
      final count = _asIntValue(point['count']);
      hourMap[hour] = count;
    }
    return List<int>.generate(24, (index) => hourMap[index] ?? 0);
  }

  int _sumWindow(List<int> counts, int startHour) {
    final endHour = math.min(startHour + 2, 23);
    var total = 0;
    for (var hour = startHour; hour <= endHour; hour++) {
      total += counts[hour];
    }
    return total;
  }

  void _updatePointer(Offset localPosition, double width) {
    if (width <= 0) return;
    final stepX = width / 23;
    final hoveredHour = (localPosition.dx / stepX).round().clamp(0, 23);
    final windowStart = math.min(hoveredHour, 21);
    setState(() {
      _pointerPosition = localPosition;
      _activeWindowStart = windowStart;
    });
  }

  void _clearPointer() {
    if (_pointerPosition == null && _activeWindowStart == null) return;
    setState(() {
      _pointerPosition = null;
      _activeWindowStart = null;
    });
  }

  String _formatHourRange(int startHour) {
    final endHour = math.min(startHour + 2, 23);
    final start = '${startHour.toString().padLeft(2, '0')}:00';
    final end = '${endHour.toString().padLeft(2, '0')}:59';
    return '$start - $end';
  }

  List<_TrafficWindowSummary> _buildTopWindows(List<int> counts) {
    final windows = List<_TrafficWindowSummary>.generate(22, (index) {
      return _TrafficWindowSummary(startHour: index, total: _sumWindow(counts, index));
    })..sort((a, b) => b.total.compareTo(a.total));

    return windows.where((window) => window.total > 0).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final maxCount = counts.fold<int>(1, (maxValue, count) => math.max(maxValue, count));
    final topWindows = _buildTopWindows(counts);
    final selectedDayTraffic = widget.trafficDays.fold<int>(
      0,
      (sum, day) => sum + (day['day']?.toString() == widget.selectedDay ? _asIntValue(day['count']) : 0),
    );

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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Traffic by Hour',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.formatDayLabel(widget.selectedDay)} · $selectedDayTraffic customers',
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              _CalendarDayButton(
                label: widget.formatDayLabel(widget.selectedDay, compact: true),
                onTap: widget.onPickDay,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
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
                              size: Size(chartWidth, 180),
                              painter: _LineChartPainter(
                                counts: counts,
                                maxCount: maxCount,
                                progress: Curves.easeOutCubic.transform(widget.animation.value),
                                activeWindowStart: _activeWindowStart,
                              ),
                            );
                          },
                        ),
                        if (counts.every((count) => count == 0))
                          const Center(
                            child: Text(
                              'No customer traffic for the selected day',
                              style: TextStyle(fontSize: 12, color: AppColors.textHint),
                            ),
                          ),
                        if (_activeWindowStart != null && _pointerPosition != null)
                          Positioned(
                            left: math.min(_pointerPosition!.dx + 14, math.max(0.0, chartWidth - 156)),
                            top: math.max(8, _pointerPosition!.dy - 70),
                            child: _TrafficTooltip(
                              rangeLabel: _formatHourRange(_activeWindowStart!),
                              customerCount: _sumWindow(counts, _activeWindowStart!),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12 AM', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              Text('6 AM', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              Text('12 PM', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              Text('6 PM', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
              Text('11 PM', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          if (topWindows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(topWindows.length, (index) {
                final window = topWindows[index];
                final color = [AppColors.warning, AppColors.secondary, AppColors.primary][index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#${index + 1} ${_formatHourRange(window.startHour)} · ${window.total} customers',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _NetProfitChartCard extends StatefulWidget {
  final List<Map<String, dynamic>> profitChart;
  final String selectedMonth;
  final Animation<double> animation;
  final String Function(String rawMonth, {bool compact}) formatMonthLabel;
  final VoidCallback onPickMonth;

  const _NetProfitChartCard({
    required this.profitChart,
    required this.selectedMonth,
    required this.animation,
    required this.formatMonthLabel,
    required this.onPickMonth,
  });

  @override
  State<_NetProfitChartCard> createState() => _NetProfitChartCardState();
}

class _NetProfitChartCardState extends State<_NetProfitChartCard> {
  Offset? _pointerPosition;
  int? _activeIndex;

  void _updatePointer(Offset localPosition, double width) {
    final pointCount = widget.profitChart.length;
    if (width <= 0 || pointCount == 0) return;
    final divisor = math.max(1, pointCount - 1);
    final stepX = width / divisor;
    final index = (localPosition.dx / stepX).round().clamp(0, pointCount - 1);
    setState(() {
      _pointerPosition = localPosition;
      _activeIndex = index;
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
    final netValues = widget.profitChart.map((point) => _asDoubleValue(point['netProfit'])).toList();
    final hasData = netValues.any((value) => value != 0);
    final minValue = netValues.isEmpty ? 0.0 : math.min(0.0, netValues.reduce(math.min));
    final maxValue = netValues.isEmpty ? 0.0 : math.max(0.0, netValues.reduce(math.max));
    final rangeLabel = widget.profitChart.isEmpty
        ? 'No data available'
      : '${widget.formatMonthLabel(widget.profitChart.first['month']?.toString() ?? '', compact: true)} to ${widget.formatMonthLabel(widget.selectedMonth, compact: true)}';

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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Net Profit',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '12-month trend ending on ${widget.formatMonthLabel(widget.selectedMonth)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              _CalendarDayButton(
                label: widget.formatMonthLabel(widget.selectedMonth, compact: true),
                onTap: widget.onPickMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
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
                              size: Size(chartWidth, 200),
                              painter: _ProfitLineChartPainter(
                                values: netValues,
                                minValue: minValue,
                                maxValue: maxValue,
                                progress: Curves.easeOutCubic.transform(widget.animation.value),
                                activeIndex: _activeIndex,
                              ),
                            );
                          },
                        ),
                        if (!hasData)
                          const Center(
                            child: Text(
                              'No net profit data for the selected range',
                              style: TextStyle(fontSize: 12, color: AppColors.textHint),
                            ),
                          ),
                        if (_activeIndex != null && _pointerPosition != null && widget.profitChart.isNotEmpty)
                          Positioned(
                            left: math.min(_pointerPosition!.dx + 14, math.max(0.0, chartWidth - 184)),
                            top: math.max(8, _pointerPosition!.dy - 78),
                            child: _NetProfitTooltip(
                              dayLabel: widget.formatMonthLabel(widget.profitChart[_activeIndex!]['month']?.toString() ?? ''),
                              netProfit: _asDoubleValue(widget.profitChart[_activeIndex!]['netProfit']),
                              customers: _asIntValue(widget.profitChart[_activeIndex!]['customers']),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (widget.profitChart.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.formatMonthLabel(widget.profitChart.first['month']?.toString() ?? '', compact: true),
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
                Text(
                  widget.formatMonthLabel(widget.profitChart[widget.profitChart.length ~/ 2]['month']?.toString() ?? '', compact: true),
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
                Text(
                  widget.formatMonthLabel(widget.selectedMonth, compact: true),
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(rangeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _CalendarDayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CalendarDayButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime firstMonth;
  final DateTime lastMonth;

  const _MonthPickerDialog({
    required this.initialMonth,
    required this.firstMonth,
    required this.lastMonth,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      widget.lastMonth.year - widget.firstMonth.year + 1,
      (index) => widget.firstMonth.year + index,
    );
    final availableMonths = _availableMonthsForYear(_selectedYear, widget.firstMonth, widget.lastMonth);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Select month'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: 'Year'),
              items: years
                  .map((year) => DropdownMenuItem<int>(value: year, child: Text('$year')))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedYear = value);
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableMonths.map((month) {
                final isSelected = month.year == widget.initialMonth.year && month.month == widget.initialMonth.month;
                return ChoiceChip(
                  label: Text(DateFormat('MMM').format(month)),
                  selected: isSelected,
                  onSelected: (_) => Navigator.of(context).pop(month),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}

class _TrafficTooltip extends StatelessWidget {
  final String rangeLabel;
  final int customerCount;

  const _TrafficTooltip({required this.rangeLabel, required this.customerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
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
          Text(rangeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '$customerCount customers',
            style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NetProfitTooltip extends StatelessWidget {
  final String dayLabel;
  final double netProfit;
  final int customers;

  const _NetProfitTooltip({required this.dayLabel, required this.netProfit, required this.customers});

  @override
  Widget build(BuildContext context) {
    final color = netProfit >= 0 ? AppColors.success : AppColors.error;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
          Text(dayLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(netProfit),
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$customers customers',
            style: const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _TrafficWindowSummary {
  final int startHour;
  final int total;

  const _TrafficWindowSummary({required this.startHour, required this.total});
}

class _LineChartPainter extends CustomPainter {
  final List<int> counts;
  final int maxCount;
  final double progress;
  final int? activeWindowStart;

  _LineChartPainter({
    required this.counts,
    required this.maxCount,
    required this.progress,
    required this.activeWindowStart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final stepX = width / (counts.length - 1);

    if (activeWindowStart != null) {
      final left = math.max(0.0, (activeWindowStart! * stepX) - (stepX / 2));
      final right = math.min(width, ((activeWindowStart! + 2) * stepX) + (stepX / 2));
      final highlightPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.09);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(left, 0, right, height), const Radius.circular(12)),
        highlightPaint,
      );

      final guideX = stepX * (activeWindowStart! + 1);
      final guidePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(guideX, 0), Offset(guideX, height), guidePaint);
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
      final y = height - (ratio * height * 0.84 * progress) - (height * 0.08);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(0, height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(width, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.30 * progress),
          AppColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
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

    final peakValue = counts.reduce(math.max);
    for (var index = 0; index < points.length; index++) {
      if (counts[index] == peakValue && peakValue > 0) {
        canvas.drawCircle(points[index], 5 * progress, Paint()..color = AppColors.warning);
        canvas.drawCircle(points[index], 3 * progress, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeWindowStart != activeWindowStart ||
        oldDelegate.counts != counts ||
        oldDelegate.maxCount != maxCount;
  }
}

class _ProfitLineChartPainter extends CustomPainter {
  final List<double> values;
  final double minValue;
  final double maxValue;
  final double progress;
  final int? activeIndex;

  _ProfitLineChartPainter({
    required this.values,
    required this.minValue,
    required this.maxValue,
    required this.progress,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final topPadding = 14.0;
    final bottomPadding = 18.0;
    final usableHeight = height - topPadding - bottomPadding;
    final range = (maxValue - minValue).abs() < 0.001 ? 1.0 : (maxValue - minValue);
    final divisor = math.max(1, values.length - 1);
    final stepX = values.isEmpty ? width : width / divisor;

    final gridPaint = Paint()
      ..color = AppColors.glassBorder
      ..strokeWidth = 0.5;
    for (var index = 0; index <= 4; index++) {
      final y = topPadding + (usableHeight * index / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final baselineRatio = (0 - minValue) / range;
    final baselineY = topPadding + ((1 - baselineRatio) * usableHeight);
    final baselinePaint = Paint()
      ..color = AppColors.textHint.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baselineY), Offset(width, baselineY), baselinePaint);

    if (activeIndex != null && values.isNotEmpty) {
      final guideX = stepX * activeIndex!;
      final guidePaint = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(guideX, 0), Offset(guideX, height), guidePaint);
    }

    if (values.isEmpty || values.every((value) => value == 0)) {
      return;
    }

    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = stepX * index;
      final ratio = (values[index] - minValue) / range;
      final y = topPadding + ((1 - ratio) * usableHeight * progress);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, baselineY);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, baselineY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.secondary.withValues(alpha: 0.22 * progress),
          AppColors.secondary.withValues(alpha: 0.03),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final controlPoint = previous.dx + ((current.dx - previous.dx) / 2);
      linePath.cubicTo(controlPoint, previous.dy, controlPoint, current.dy, current.dx, current.dy);
    }

    final linePaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    if (activeIndex != null && activeIndex! < points.length) {
      final point = points[activeIndex!];
      final pointColor = values[activeIndex!] >= 0 ? AppColors.success : AppColors.error;
      canvas.drawCircle(point, 6, Paint()..color = pointColor);
      canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfitLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.progress != progress ||
        oldDelegate.activeIndex != activeIndex;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

int _asIntValue(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDoubleValue(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _tryParseDay(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime? _tryParseMonth(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse('$value-01');
}

List<DateTime> _availableMonthsForYear(int year, DateTime firstMonth, DateTime lastMonth) {
  final first = DateTime(firstMonth.year, firstMonth.month);
  final last = DateTime(lastMonth.year, lastMonth.month);
  final months = <DateTime>[];

  for (var month = 1; month <= 12; month += 1) {
    final candidate = DateTime(year, month);
    if (candidate.isBefore(first) || candidate.isAfter(last)) {
      continue;
    }
    months.add(candidate);
  }

  return months;
}

String _cleanError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}

String _formatCurrency(double value) {
  final prefix = value < 0 ? '-\$' : '\$';
  return '$prefix${value.abs().toStringAsFixed(2)}';
}
