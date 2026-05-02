import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/page_transitions.dart';
import '../../models/queue_model.dart';
import 'business_detail_screen.dart';

class CustomerQueueListScreen extends StatefulWidget {
  final VoidCallback? onExplorePressed;
  const CustomerQueueListScreen({super.key, this.onExplorePressed});

  @override
  State<CustomerQueueListScreen> createState() => _CustomerQueueListScreenState();
}

class _CustomerQueueListScreenState extends State<CustomerQueueListScreen> {
  Timer? _refreshTimer;
  final Map<String, int> _prevPositions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        Provider.of<QueueProvider>(context, listen: false).loadUserQueues();
      }
      // Poll every 30 seconds for position updates + trigger notifications
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshAndNotify());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAndNotify() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return;
    final qProvider = Provider.of<QueueProvider>(context, listen: false);
    await qProvider.loadUserQueues();
    if (!mounted) return;
    // Check for positions approaching
    for (final entry in qProvider.userActiveQueues) {
      final prev = _prevPositions[entry.id];
      final current = entry.peopleAhead ?? (entry.position - 1);
      if (prev != null && prev > 2 && current <= 2 && current >= 0) {
        _showPositionAlert(entry);
      }
      _prevPositions[entry.id] = current;
    }
  }

  void _showPositionAlert(QueueEntryModel entry) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Your Turn is Near! 🔔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              entry.businessName != null
                  ? 'Only ${entry.peopleAhead ?? (entry.position - 1)} person(s) ahead of you at ${entry.businessName}!'
                  : 'You\'re almost up, get ready!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<QueueProvider, BusinessProvider>(
      builder: (context, qProvider, bProvider, _) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final queues = qProvider.userActiveQueues;

        if (queues.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (auth.currentUser != null) {
              await qProvider.loadUserQueues();
            }
          },
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: queues.length,
            itemBuilder: (context, index) {
              final entry = queues[index];
              final business = bProvider.getBusinessById(entry.businessId);
              final isServing = entry.status == QueueEntryStatus.serving;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 450 + (index * 80)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _QueueEntryCard(
                  entry: entry,
                  business: business,
                  isServing: isServing,
                  onViewShop: () {
                    if (business != null) {
                      Navigator.push(context, SmoothPageRoute(page: BusinessDetailScreen(business: business)));
                    }
                  },
                  onCancel: () async {
                    final confirmed = await _showCancelDialog(context);
                    if (confirmed && context.mounted) {
                      await qProvider.cancelSpecificQueue(entry.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Left queue successfully')),
                        );
                      }
                    }
                  },
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
                  gradient: const LinearGradient(
                    colors: [AppColors.surfaceLight, AppColors.surface],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: const Icon(Icons.hourglass_empty_rounded, size: 52, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 28),
            const Text('No active queues', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Join from a business page', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: widget.onExplorePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: const Text('Explore Businesses', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
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
            const Text('Leave Queue?'),
          ],
        ),
        content: const Text('You will lose your current position.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep My Spot'),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: const Text('Leave Queue'),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
}

class _QueueEntryCard extends StatefulWidget {
  final QueueEntryModel entry;
  final dynamic business;
  final bool isServing;
  final VoidCallback onViewShop;
  final VoidCallback onCancel;

  const _QueueEntryCard({
    required this.entry,
    required this.business,
    required this.isServing,
    required this.onViewShop,
    required this.onCancel,
  });

  @override
  State<_QueueEntryCard> createState() => _QueueEntryCardState();
}

class _QueueEntryCardState extends State<_QueueEntryCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isServing) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAhead = widget.entry.peopleAhead ?? (widget.entry.position > 0 ? widget.entry.position - 1 : 0);
    final waitTime = widget.entry.waitTimeEstimate;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isServing
                  ? AppColors.secondary.withValues(alpha: 0.3 + 0.2 * _pulseController.value)
                  : AppColors.glassBorder,
              width: widget.isServing ? 1.5 : 0.5,
            ),
            boxShadow: widget.isServing
                ? [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.08 + 0.08 * _pulseController.value), blurRadius: 20, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (widget.isServing ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.12),
                        (widget.isServing ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.business?.categoryIcon ?? '🏪',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.business?.name ?? widget.entry.businessName ?? 'Business',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (widget.entry.notes != null && widget.entry.notes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '🛒 ${widget.entry.notes}',
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: widget.isServing ? AppColors.servingGradient : null,
                          color: widget.isServing ? null : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isServing ? Icons.flash_on_rounded : Icons.schedule_rounded,
                              size: 14,
                              color: widget.isServing ? Colors.white : AppColors.primaryLight,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.isServing ? 'YOUR TURN NOW!' : 'Queue #${widget.entry.position}',
                              style: TextStyle(
                                color: widget.isServing ? Colors.white : AppColors.primaryLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: widget.isServing ? 0.5 : 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Dynamic wait time row
            if (!widget.isServing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people_outline_rounded, size: 16, color: AppColors.textHint),
                        const SizedBox(width: 6),
                        Text('$peopleAhead ahead', style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text('Est: $waitTime', style: const TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            if (widget.entry.productDurationMinutes > 0 || widget.entry.totalPrice > 0) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (widget.entry.productDurationMinutes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timelapse_rounded, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 6),
                          Text(
                            'Service: ${widget.entry.durationLabel}',
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  if (widget.entry.totalPrice > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payments_outlined, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          if (widget.entry.discountAmount > 0) ...[
                            Text(
                              '\$${widget.entry.originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '\$${widget.entry.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.divider.withValues(alpha: 0.5), height: 1),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onViewShop,
                  icon: const Icon(Icons.storefront_outlined, size: 16),
                  label: const Text('Shop', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
                ),
                const Spacer(),
                const SizedBox(width: 4),
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
                      onTap: widget.onCancel,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 15, color: AppColors.error),
                            SizedBox(width: 5),
                            Text('Leave', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
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
    );
  }
}

