import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/loading_widget.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment_model.dart';
import 'package:intl/intl.dart';

class AppointmentManagementScreen extends StatefulWidget {
  const AppointmentManagementScreen({super.key});

  @override
  State<AppointmentManagementScreen> createState() => _AppointmentManagementScreenState();
}

class _AppointmentManagementScreenState extends State<AppointmentManagementScreen> {
  DateTime _selectedDate = DateTime.now();
  AppointmentProvider? _appointmentProvider;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _appointmentProvider?.unsubscribeFromBusinessAppointments();
    super.dispose();
  }

  void _loadAppointments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.getBusinessByOwnerId(auth.currentUser?.id ?? '');

      if (business != null) {
        _appointmentProvider ??= Provider.of<AppointmentProvider>(context, listen: false);
        _appointmentProvider!.subscribeToBusinessAppointments(business.id, date: _selectedDate);
        _appointmentProvider!.loadBusinessAppointments(business.id, date: _selectedDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDateHeader(),
        Expanded(
          child: Consumer<AppointmentProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.businessAppointments.isEmpty) {
                return const LoadingWidget(message: 'Loading appointments...');
              }

              if (provider.businessAppointments.isEmpty) {
                return Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      return Opacity(opacity: val, child: Transform.translate(
                        offset: Offset(0, 20 * (1 - val)), child: child,
                      ));
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.event_note_rounded, size: 48, color: AppColors.textHint),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No appointments for this day',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadAppointments(),
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.businessAppointments.length,
                  itemBuilder: (context, index) {
                  final appointment = provider.businessAppointments[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 400 + (index * 60)),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      return Opacity(opacity: val, child: Transform.translate(
                        offset: Offset(0, 16 * (1 - val)), child: child,
                      ));
                    },
                    child: AppointmentCard(
                      appointment: appointment,
                      isBusiness: true,
                      onComplete: () {
                        provider.updateAppointmentStatus(appointment.id, AppointmentStatus.completed);
                      },
                      onCancel: () {
                        provider.updateAppointmentStatus(appointment.id, AppointmentStatus.cancelled);
                      },
                    ),
                  );
                },
              ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceLight, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDateButton(Icons.chevron_left, () {
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
            _loadAppointments();
          }),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadAppointments();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: isToday ? AppColors.primaryGradient : null,
                color: isToday ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: isToday ? null : Border.all(color: AppColors.glassBorder, width: 0.5),
                boxShadow: isToday ? [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 8),
                ] : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 15,
                      color: isToday ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    isToday ? 'Today' : DateFormat('EEE, MMM dd').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDateButton(Icons.chevron_right, () {
            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
            _loadAppointments();
          }),
        ],
      ),
    );
  }

  Widget _buildDateButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 22),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
      ),
    );
  }
}
