import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';
import '../screens/shared/notification_center_screen.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
            ),
            icon: Badge(
              isLabelVisible: provider.unreadCount > 0,
              label: Text(provider.unreadCount > 99 ? '99+' : provider.unreadCount.toString()),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.glassGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: Icon(
                  provider.unreadCount > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_rounded,
                  size: 20,
                  color: provider.unreadCount > 0 ? AppColors.primaryLight : AppColors.textHint,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}