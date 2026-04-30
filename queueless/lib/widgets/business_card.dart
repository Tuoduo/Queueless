import 'package:flutter/material.dart';
import '../../models/business_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/category_themes.dart';
import 'category_background.dart';

class BusinessCard extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onTap;

  const BusinessCard({
    super.key,
    required this.business,
    required this.onTap,
  });

  @override
  State<BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<BusinessCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isPressed
                  ? CategoryThemes.getTheme(widget.business.category).primaryColor.withOpacity(0.4)
                  : AppColors.glassBorder,
              width: _isPressed ? 1.0 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? CategoryThemes.getTheme(widget.business.category).primaryColor.withOpacity(0.12)
                    : Colors.black.withOpacity(0.15),
                blurRadius: _isPressed ? 20 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CategoryBackground(
            theme: CategoryThemes.getTheme(widget.business.category),
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Subtle gradient overlay from top corner
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          CategoryThemes.getTheme(widget.business.category).primaryColor.withOpacity(0.15),
                          CategoryThemes.getTheme(widget.business.category).primaryColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with gradient background
                      Container(
                        height: 68,
                        width: 68,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              CategoryThemes.getTheme(widget.business.category).primaryColor.withOpacity(0.2),
                              CategoryThemes.getTheme(widget.business.category).accentColor.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: CategoryThemes.getTheme(widget.business.category).primaryColor.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.business.categoryIcon,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + Rating Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.business.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildRatingChip(context),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Category + Service Type
                            Row(
                              children: [
                                _buildCategoryBadge(context),
                                const SizedBox(width: 8),
                                _buildServiceTypeBadge(context),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Description
                            Text(
                              widget.business.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Address
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 13,
                                    color: AppColors.textHint.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.business.address,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    size: 12, color: AppColors.textHint),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.vip.withOpacity(0.18),
            AppColors.vip.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.vip, size: 13),
          const SizedBox(width: 3),
          Text(
            widget.business.rating.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.vip,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        widget.business.categoryDisplayName,
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildServiceTypeBadge(BuildContext context) {
    final isQueue = widget.business.serviceType == ServiceType.queue;
    final isAppointment = widget.business.serviceType == ServiceType.appointment;
    final color = isQueue
        ? AppColors.secondary
        : (isAppointment ? AppColors.info : AppColors.warning);
    final label =
        isQueue ? 'Queue' : (isAppointment ? 'Appointment' : 'Both');
    final icon = isQueue
        ? Icons.people_outlined
        : (isAppointment ? Icons.calendar_month : Icons.swap_horiz);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
