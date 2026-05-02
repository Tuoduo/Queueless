import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/queue_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/queue_provider.dart';
import '../../../widgets/loading_widget.dart';

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({super.key});

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _businessId;
  QueueProvider? _queueProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging && _businessId != null) {
        Provider.of<QueueProvider>(context, listen: false).loadDeliveredOrders(_businessId!);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final bp = Provider.of<BusinessProvider>(context, listen: false);
      final business = bp.getBusinessByOwnerId(auth.currentUser?.id ?? '');
      if (business != null) {
        _businessId = business.id;
        _queueProvider = Provider.of<QueueProvider>(context, listen: false);
        _queueProvider!.subscribeToQueue(business.id);
        _queueProvider!.loadQueue(business.id);
        _queueProvider!.loadDeliveredOrders(business.id, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _queueProvider?.unsubscribeFromQueue();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueProvider>(
      builder: (context, qp, _) {
        if (qp.isLoading && qp.currentQueue == null) {
          return const LoadingWidget(message: 'Loading...');
        }
        if (qp.error != null) {
          return Center(child: Text('Error: ${qp.error}'));
        }

        final queue = qp.currentQueue;
        if (queue == null) {
          return const Center(child: Text('Queue not found.'));
        }

        return Column(
          children: [
            Container(
              color: AppColors.background,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: [
                  Tab(text: 'Orders (${qp.businessQueue.length})'),
                  const Tab(text: 'Orders History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ActiveOrdersTab(queue: queue, qp: qp),
                  _DeliveredTab(businessId: queue.businessId, qp: qp),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActiveOrdersTab extends StatelessWidget {
  final QueueModel queue;
  final QueueProvider qp;

  const _ActiveOrdersTab({required this.queue, required this.qp});

  @override
  Widget build(BuildContext context) {
    final servingEntries = qp.businessQueue.where((entry) => entry.status == QueueEntryStatus.serving).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final waitingEntries = qp.businessQueue.where((entry) => entry.status == QueueEntryStatus.waiting).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => qp.loadQueue(queue.businessId),
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: (servingEntries.isEmpty && waitingEntries.isEmpty)
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(22)),
                            child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: AppColors.secondary),
                          ),
                          const SizedBox(height: 16),
                          const Text('No active orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('All orders completed!', style: TextStyle(color: AppColors.textHint)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                  children: [
                    if (servingEntries.isNotEmpty) ...[
                      const _SectionHeader(
                        icon: Icons.flash_on_rounded,
                        title: 'Serving Now',
                        subtitle: 'These customers are currently being served.',
                      ),
                      const SizedBox(height: 10),
                      ...servingEntries.map((entry) => _QueueOrderCard(entry: entry, isServing: true)).toList(),
                      const SizedBox(height: 20),
                    ],
                    _SectionHeader(
                      icon: Icons.swap_vert_rounded,
                      title: 'Waiting Queue',
                      subtitle: waitingEntries.length > 1
                          ? 'Drag customers to move them forward or backward.'
                          : 'New customers will appear here in queue order.',
                    ),
                    const SizedBox(height: 10),
                    if (waitingEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: const Text('Nobody is waiting right now.', style: TextStyle(color: AppColors.textHint)),
                      )
                    else
                      DragBoundary(
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            dragBoundaryProvider: DragBoundary.forRectOf,
                            itemCount: waitingEntries.length,
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final reordered = List<QueueEntryModel>.from(waitingEntries);
                              final moved = reordered.removeAt(oldIndex);
                              reordered.insert(newIndex, moved);
                              try {
                                await qp.reorderWaitingEntries(
                                  queue.businessId,
                                  reordered.map((entry) => entry.id).toList(),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Queue order updated.')),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context, index) {
                              final entry = waitingEntries[index];
                              return _QueueOrderCard(
                                key: ValueKey(entry.id),
                                entry: entry,
                                dragHandle: ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.drag_indicator_rounded, color: AppColors.textHint),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomActionBar(queue: queue, qp: qp),
        ),
      ],
    );
  }
}

class _QueueOrderCard extends StatelessWidget {
  final QueueEntryModel entry;
  final bool isServing;
  final Widget? dragHandle;

  const _QueueOrderCard({super.key, required this.entry, this.isServing = false, this.dragHandle});

  @override
  Widget build(BuildContext context) {
    final accentColor = isServing ? AppColors.secondary : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isServing ? AppColors.secondary.withValues(alpha: 0.35) : AppColors.glassBorder,
          width: isServing ? 1.2 : 0.5,
        ),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isServing ? AppColors.servingGradient : AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isServing
                  ? const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22)
                  : Text(
                      '${entry.position}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (entry.isVIP)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.vip.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.vip)),
                        ),
                      if (isServing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Serving', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                        ),
                      ],
                    ],
                  ),
                  if ((entry.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                        children: [
                          const TextSpan(text: 'Order: ', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          TextSpan(text: entry.notes!),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniInfoChip(icon: Icons.payments_outlined, label: '\$${entry.totalPrice.toStringAsFixed(2)}', color: AppColors.secondary),
                      _MiniInfoChip(icon: entry.paymentMethod == 'now' ? Icons.credit_card_rounded : Icons.storefront_outlined, label: entry.paymentMethodLabel, color: entry.paymentMethod == 'now' ? AppColors.primary : AppColors.success),
                      if (entry.discountAmount > 0)
                        _MiniInfoChip(icon: Icons.local_offer_outlined, label: '-\$${entry.discountAmount.toStringAsFixed(2)}', color: AppColors.success),
                      if ((entry.discountCode ?? '').isNotEmpty)
                        _MiniInfoChip(icon: Icons.confirmation_number_outlined, label: entry.discountCode!, color: AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _showQueueEntryDetails(context, entry),
                  icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  tooltip: 'Order details',
                ),
                if (dragHandle != null) dragHandle!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniInfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveredTab extends StatelessWidget {
  final String businessId;
  final QueueProvider qp;

  const _DeliveredTab({required this.businessId, required this.qp});

  @override
  Widget build(BuildContext context) {
    if (qp.isLoadingDelivered) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = qp.deliveredOrders;
    if (orders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.history_rounded, size: 44, color: AppColors.textHint),
                ),
                const SizedBox(height: 16),
                const Text('No completed orders yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Completed orders will appear here.', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => qp.loadDeliveredOrders(businessId),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final entry = orders[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if ((entry.notes ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(entry.notes!, style: const TextStyle(color: AppColors.textHint, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (entry.totalPrice > 0)
                      Text('\$${entry.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(_formatTime(entry.joinedAt), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
                IconButton(
                  onPressed: () => _showQueueEntryDetails(context, entry),
                  icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final QueueModel queue;
  final QueueProvider qp;

  const _BottomActionBar({required this.queue, required this.qp});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: _PauseButton(
              businessId: queue.businessId,
              isPaused: queue.isPaused,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AnimatedOpacity(
              opacity: qp.businessQueue.isEmpty ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: qp.businessQueue.isEmpty
                      ? []
                      : [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton.icon(
                  onPressed: qp.businessQueue.isEmpty ? null : () => qp.callNext(queue.businessId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 20),
                  label: const Text('Next', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseButton extends StatefulWidget {
  final String businessId;
  final bool isPaused;

  const _PauseButton({required this.businessId, this.isPaused = false});

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
  bool _loading = false;

  bool get _paused => Provider.of<QueueProvider>(context, listen: false).currentQueue?.isPaused ?? widget.isPaused;

  Future<void> _toggle() async {
    setState(() => _loading = true);
    try {
      final qp = Provider.of<QueueProvider>(context, listen: false);
      if (_paused) {
        await qp.resumeQueue(widget.businessId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queue resumed.')));
        }
      } else {
        await _confirm();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Pause Queue'),
          ],
        ),
        content: const Text('New customers will be paused. Current customers will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pause'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await Provider.of<QueueProvider>(context, listen: false).pauseQueue(widget.businessId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queue paused.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueProvider>(
      builder: (context, qp, _) {
        final paused = qp.currentQueue?.isPaused ?? false;
        return OutlinedButton.icon(
          onPressed: _loading ? null : _toggle,
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
          label: Text(paused ? 'Resume' : 'Pause', style: const TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: paused ? AppColors.success : AppColors.warning,
            side: BorderSide(color: (paused ? AppColors.success : AppColors.warning).withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      },
    );
  }
}

void _showQueueEntryDetails(BuildContext context, QueueEntryModel entry) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.of(context).size.height * 0.78;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(label: 'Queue position', value: entry.position.toString()),
                  _DetailRow(label: 'Purchased items', value: (entry.notes ?? '').isNotEmpty ? entry.notes! : 'Not specified'),
                  _DetailRow(label: 'Total paid', value: '\$${entry.totalPrice.toStringAsFixed(2)}'),
                  _DetailRow(label: 'Payment method', value: entry.paymentMethodLabel),
                  _DetailRow(label: 'Discount', value: entry.discountAmount > 0 ? '-\$${entry.discountAmount.toStringAsFixed(2)}' : 'No coupon applied'),
                  _DetailRow(label: 'Coupon code', value: (entry.discountCode ?? '').isNotEmpty ? entry.discountCode! : 'No coupon applied'),
                  _DetailRow(label: 'Estimated service time', value: entry.durationLabel),
                  _DetailRow(label: 'Joined at', value: _formatDateTime(entry.joinedAt)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final year = dateTime.year.toString();
  return '$day/$month/$year ${_formatTime(dateTime)}';
}