import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/time_slot_model.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  final _uuid = const Uuid();
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadSlots();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _loadSlots() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final bProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = bProvider.getBusinessByOwnerId(auth.currentUser!.id);
      
      if (business != null) {
        Provider.of<AppointmentProvider>(context, listen: false)
            .loadAvailableSlots(business.id, _selectedDate, includeBooked: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Today: ${DateFormat('d MMM').format(DateTime.now())}',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),
            _buildDatePicker(),
            Container(height: 1, color: AppColors.divider),
            Expanded(
              child: _buildSlotsList(),
            ),
          ],
        ),
        // Animated FAB
        Positioned(
          bottom: 24,
          right: 24,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSlotCreationSheet(context),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadSlots();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 56,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                color: isSelected ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.transparent : (isToday ? AppColors.primary.withValues(alpha: 0.5) : AppColors.divider),
                ),
                boxShadow: isSelected ? [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotsList() {
    return Consumer<AppointmentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final slots = provider.availableSlots;

        if (slots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Icon(Icons.event_busy, size: 52, color: AppColors.textHint),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('No slots for this day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Tap + to create time slots', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: slot.isBooked ? AppColors.error.withValues(alpha: 0.3) : AppColors.glassBorder,
                    width: 0.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: slot.isBooked 
                          ? [AppColors.error.withValues(alpha: 0.15), AppColors.error.withValues(alpha: 0.05)]
                          : [AppColors.secondary.withValues(alpha: 0.15), AppColors.secondary.withValues(alpha: 0.05)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      slot.isBooked ? Icons.event_busy : Icons.access_time,
                      color: slot.isBooked ? AppColors.error : AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    slot.timeRange,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Text(
                    DateFormat('EEEE, MMM d').format(slot.startTime),
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: slot.isBooked 
                        ? AppColors.error.withValues(alpha: 0.1) 
                        : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      slot.isBooked ? 'BOOKED' : 'OPEN',
                      style: TextStyle(
                        color: slot.isBooked ? AppColors.error : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSlotCreationSheet(BuildContext context) {
    int startHour = 9;
    int startMinute = 0;
    int endHour = 10;
    int endMinute = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: const Border(
                top: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.schedule, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Create Time Slot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          DateFormat('EEEE, MMMM d').format(_selectedDate),
                          style: const TextStyle(color: AppColors.primaryLight, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Time display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.surfaceLight, AppColors.surface],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Start time
                      _buildTimeWheel(
                        label: 'START',
                        hour: startHour,
                        minute: startMinute,
                        color: AppColors.secondary,
                        onHourChanged: (h) => setSheetState(() {
                          startHour = h;
                          if (endHour <= startHour) endHour = startHour + 1;
                        }),
                        onMinuteChanged: (m) => setSheetState(() => startMinute = m),
                      ),
                      // Arrow
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          ShaderMask(
                            shaderCallback: (b) => AppColors.heroGradient.createShader(b),
                            child: const Icon(Icons.arrow_forward_rounded, size: 28, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${endHour - startHour}h ${(endMinute - startMinute).abs()}m',
                            style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                          ),
                        ],
                      ),
                      // End time
                      _buildTimeWheel(
                        label: 'END',
                        hour: endHour,
                        minute: endMinute,
                        color: AppColors.primary,
                        onHourChanged: (h) => setSheetState(() => endHour = h),
                        onMinuteChanged: (m) => setSheetState(() => endMinute = m),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Create button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final auth = Provider.of<AuthProvider>(ctx, listen: false);
                      final bProvider = Provider.of<BusinessProvider>(ctx, listen: false);
                      final business = bProvider.getBusinessByOwnerId(auth.currentUser!.id);
                      
                      if (business != null) {
                        final startTime = DateTime(
                          _selectedDate.year, _selectedDate.month, _selectedDate.day,
                          startHour, startMinute,
                        );
                        final endTime = DateTime(
                          _selectedDate.year, _selectedDate.month, _selectedDate.day,
                          endHour, endMinute,
                        );
                        
                        await Provider.of<AppointmentProvider>(ctx, listen: false).addSlot(
                          TimeSlotModel(
                            id: _uuid.v4(),
                            businessId: business.id,
                            startTime: startTime,
                            endTime: endTime,
                          ),
                        );
                        
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Slot created: ${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}'),
                                ],
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Create Slot', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeWheel({
    required String label,
    required int hour,
    required int minute,
    required Color color,
    required Function(int) onHourChanged,
    required Function(int) onMinuteChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hour selector
            GestureDetector(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                );
                if (time != null) {
                  onHourChanged(time.hour);
                  onMinuteChanged(time.minute);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
