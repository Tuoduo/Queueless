import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/appointment_model.dart';
import 'package:intl/intl.dart';

class CustomerAppointmentListScreen extends StatefulWidget {
  final VoidCallback? onExplorePressed;
  const CustomerAppointmentListScreen({super.key, this.onExplorePressed});

  @override
  State<CustomerAppointmentListScreen> createState() => _CustomerAppointmentListScreenState();
}

class _CustomerAppointmentListScreenState extends State<CustomerAppointmentListScreen> {
  AppointmentProvider? _appointmentProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        _appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
        _appointmentProvider!.subscribeToCustomerAppointments(auth.currentUser!.id);
        _appointmentProvider!.loadCustomerAppointments();
      }
    });
  }

  @override
  void dispose() {
    _appointmentProvider?.unsubscribeFromCustomerAppointments();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppointmentProvider, BusinessProvider>(
      builder: (context, aProvider, bProvider, _) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final appointments = aProvider.activeCustomerAppointments;

        if (appointments.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (auth.currentUser != null) {
              await aProvider.loadCustomerAppointments();
            }
          },
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              final business = bProvider.getBusinessById(appointment.businessId);
              final statusColor = _getStatusColor(appointment.status);

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 450 + (index * 70)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left status accent bar
                        Container(
                          width: 4,
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [statusColor, statusColor.withValues(alpha: 0.2)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            statusColor.withValues(alpha: 0.12),
                                            statusColor.withValues(alpha: 0.04),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        business?.categoryIcon ?? '🏥',
                                        style: const TextStyle(fontSize: 26),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            business?.name ?? 'Unknown Business',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 6),
                                          // Date & time pill
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.schedule_rounded, size: 13, color: AppColors.primaryLight),
                                                const SizedBox(width: 5),
                                                Text(
                                                  DateFormat('EEE, MMM d • HH:mm').format(appointment.dateTime),
                                                  style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (appointment.serviceName != null && appointment.serviceName!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              appointment.serviceName!,
                                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                          if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              appointment.notes!,
                                              style: TextStyle(color: AppColors.textHint, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (appointment.serviceDurationMinutes > 0 || appointment.displayPrice != null) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                if (appointment.serviceDurationMinutes > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.surfaceLight,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.timelapse_rounded, size: 13, color: AppColors.primaryLight),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          appointment.durationLabel,
                                                          style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (appointment.displayPrice != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.surfaceLight,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.payments_outlined, size: 13, color: AppColors.secondary),
                                                        const SizedBox(width: 5),
                                                        if (appointment.discountAmount > 0 && appointment.originalPrice != null) ...[
                                                          Text(
                                                            '\$${appointment.originalPrice!.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              color: AppColors.textHint,
                                                              fontSize: 11,
                                                              decoration: TextDecoration.lineThrough,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                        ],
                                                        Text(
                                                          '\$${appointment.displayPrice!.toStringAsFixed(2)}',
                                                          style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w700),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(color: AppColors.divider.withValues(alpha: 0.5), height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getStatusIcon(appointment.status), size: 13, color: statusColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            _getStatusLabel(appointment.status),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (appointment.status == AppointmentStatus.pending || appointment.status == AppointmentStatus.confirmed)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            onTap: () async {
                                              final confirmed = await _showCancelDialog(context);
                                              if (confirmed && context.mounted) {
                                                await aProvider.cancelAppointment(appointment.id);
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(12),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                                                  SizedBox(width: 5),
                                                  Text('Cancel', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(opacity: value, child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)), child: child,
          ));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.surfaceLight, AppColors.surface]),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: const Icon(Icons.calendar_today_outlined, size: 52, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 28),
            const Text('No active appointments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Book an appointment from a business page', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onExplorePressed,
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text('Explore Businesses'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending: return AppColors.warning;
      case AppointmentStatus.confirmed: return AppColors.success;
      case AppointmentStatus.completed: return AppColors.primary;
      case AppointmentStatus.cancelled: return AppColors.error;
    }
  }

  IconData _getStatusIcon(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending: return Icons.hourglass_bottom_rounded;
      case AppointmentStatus.confirmed: return Icons.check_circle_outline_rounded;
      case AppointmentStatus.completed: return Icons.done_all_rounded;
      case AppointmentStatus.cancelled: return Icons.cancel_outlined;
    }
  }

  String _getStatusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending: return 'PENDING';
      case AppointmentStatus.confirmed: return 'CONFIRMED';
      case AppointmentStatus.completed: return 'COMPLETED';
      case AppointmentStatus.cancelled: return 'CANCELLED';
    }
  }

  Future<bool> _showCancelDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Cancel Appointment?'),
          ],
        ),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Appointment'),
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: const Text('Cancel Anyway'),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
}
