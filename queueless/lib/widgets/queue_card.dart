import 'package:flutter/material.dart';
import '../../models/queue_model.dart';
import '../../core/constants/app_colors.dart';

class QueueCard extends StatefulWidget {
  final QueueEntryModel entry;
  final VoidCallback? onAction;
  final String actionLabel;
  final bool isBusiness;

  const QueueCard({
    super.key,
    required this.entry,
    this.onAction,
    this.actionLabel = 'Action',
    this.isBusiness = false,
  });

  @override
  State<QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<QueueCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.entry.status == QueueEntryStatus.serving) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isServing = widget.entry.status == QueueEntryStatus.serving;
    final statusColor = isServing ? AppColors.secondary : AppColors.primary;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isServing
                  ? AppColors.secondary.withOpacity(0.3 + 0.2 * _pulseController.value)
                  : AppColors.glassBorder,
              width: isServing ? 1.5 : 0.5,
            ),
            boxShadow: isServing
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.08 + 0.08 * _pulseController.value),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Position circle with gradient
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                gradient: isServing
                    ? AppColors.servingGradient
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: isServing
                    ? const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24)
                    : Text(
                        '${widget.entry.position}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
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
                        child: Text(
                          widget.entry.customerName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.entry.isVIP) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.vip.withOpacity(0.2),
                                AppColors.vip.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: AppColors.vip, size: 14),
                              SizedBox(width: 3),
                              Text('VIP', style: TextStyle(color: AppColors.vip, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isServing
                          ? '⚡ Currently Serving'
                          : '🕐 Wait: ${widget.entry.waitTimeEstimate}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: isServing ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.entry.notes != null && widget.entry.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.entry.notes!,
                      style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (widget.entry.productDurationMinutes > 0 || widget.entry.totalPrice > 0) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.entry.productDurationMinutes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.entry.durationLabel,
                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (widget.entry.totalPrice > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.entry.discountAmount > 0) ...[
                                  Text(
                                    '\$${widget.entry.originalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '\$${widget.entry.totalPrice.toStringAsFixed(2)}',
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
            if (widget.onAction != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: widget.onAction,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        widget.actionLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
