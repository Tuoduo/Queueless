import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../admin/admin_home_screen.dart';
import '../business/business_home_screen.dart';
import '../customer/customer_home_screen.dart';
import 'live_business_chat_screen.dart';
import 'ticket_list_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications(silent: false);
    });
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    final provider = context.read<NotificationProvider>();
    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }

    if (!mounted) return;
    final destination = _buildDestination(notification);
    if (destination == null) return;

    final route = MaterialPageRoute(builder: (_) => destination);
    if (_shouldReplaceWithShell(destination)) {
      await Navigator.of(context).pushReplacement(route);
      return;
    }

    await Navigator.of(context).push(route);
  }

  Future<void> _confirmDeleteAll(NotificationProvider provider) async {
    if (provider.notifications.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete all notifications'),
        content: const Text('This will permanently remove every notification from this account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete all', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.clearAll();
    }
  }

  Widget? _buildDestination(NotificationModel notification) {
    final auth = context.read<AuthProvider>();
    final metadata = notification.metadata ?? const <String, dynamic>{};

    switch (notification.type) {
      case 'chat_message':
        final conversationId = metadata['conversationId']?.toString() ?? notification.entityId ?? '';
        if (conversationId.isEmpty) return null;
        final businessName = metadata['businessName']?.toString();
        final customerName = metadata['customerName']?.toString();
        return LiveBusinessChatScreen(
          conversationId: conversationId,
          title: auth.isBusinessOwner
              ? ((customerName != null && customerName.trim().isNotEmpty) ? customerName : 'Customer Chat')
              : ((businessName != null && businessName.trim().isNotEmpty) ? businessName : 'Business Chat'),
          subtitle: auth.isBusinessOwner ? businessName : notification.title,
        );
      case 'queue_joined':
        return auth.isBusinessOwner
            ? const BusinessHomeScreen(initialTab: BusinessHomeTab.queue)
            : const CustomerHomeScreen(initialTab: CustomerHomeTab.queues);
      case 'queue_serving':
        return auth.isCustomer
            ? const CustomerHomeScreen(initialTab: CustomerHomeTab.queues)
            : const BusinessHomeScreen(initialTab: BusinessHomeTab.queue);
      case 'queue_done':
        return auth.isCustomer
            ? const CustomerHomeScreen(initialTab: CustomerHomeTab.history)
            : const BusinessHomeScreen(initialTab: BusinessHomeTab.queue);
      case 'appointment_booked':
      case 'appointment_status':
      case 'appointment_cancelled':
        return auth.isBusinessOwner
            ? const BusinessHomeScreen(initialTab: BusinessHomeTab.bookings)
            : const CustomerHomeScreen(initialTab: CustomerHomeTab.appointments);
      case 'ticket_created':
      case 'ticket_admin_reply':
      case 'ticket_status':
        return const TicketListScreen();
      case 'business_pending':
        return auth.isAdmin
            ? const AdminHomeScreen(initialTab: AdminHomeTab.businesses, businessesStatusFilter: '')
            : null;
      case 'business_approved':
      case 'business_rejected':
        if (auth.isBusinessOwner) {
          return const BusinessHomeScreen(initialTab: BusinessHomeTab.settings);
        }
        return auth.isAdmin
            ? const AdminHomeScreen(initialTab: AdminHomeTab.businesses, businessesStatusFilter: '')
            : null;
      default:
        if (notification.entityType == 'ticket') {
          return const TicketListScreen();
        }
        return null;
    }
  }

  bool _shouldReplaceWithShell(Widget destination) {
    return destination is CustomerHomeScreen || destination is BusinessHomeScreen || destination is AdminHomeScreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: provider.unreadCount == 0 ? null : provider.markAllAsRead,
                    child: const Text('Mark all read'),
                  ),
                  TextButton(
                    onPressed: provider.notifications.isEmpty ? null : () => _confirmDeleteAll(provider),
                    child: const Text('Delete all'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = <Widget>[
            _buildSummaryCard(provider),
            const SizedBox(height: 16),
          ];

          if (provider.error != null) {
            children.add(
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Text(provider.error!, style: const TextStyle(color: AppColors.error)),
              ),
            );
            children.add(const SizedBox(height: 16));
          }

          if (!provider.isLoading && provider.notifications.isEmpty) {
            children.add(_buildEmptyState());
          } else {
            for (final notification in provider.notifications) {
              children.add(_buildNotificationTile(provider, notification));
            }
          }

          return RefreshIndicator(
            onRefresh: provider.loadNotifications,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(NotificationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${provider.unreadCount} unread notification${provider.unreadCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 52, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('No notifications yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(
            'Queue updates, support replies, appointment changes, and new messages will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationProvider provider, NotificationModel notification) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => provider.deleteNotification(notification.id),
      background: _buildDismissBackground(alignment: Alignment.centerLeft),
      secondaryBackground: _buildDismissBackground(alignment: Alignment.centerRight),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notification.isRead ? AppColors.glassBorder : AppColors.primary.withValues(alpha: 0.35),
            width: notification.isRead ? 0.5 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          onTap: () => _handleNotificationTap(notification),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _iconColor(notification.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(notification.type), color: _iconColor(notification.type)),
          ),
          title: Text(
            notification.title,
            style: TextStyle(fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.body),
                const SizedBox(height: 8),
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'queue_done':
        return Icons.inventory_2_outlined;
      case 'queue_serving':
        return Icons.flash_on_rounded;
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'appointment_booked':
      case 'appointment_status':
      case 'appointment_cancelled':
        return Icons.event_available_rounded;
      case 'ticket_admin_reply':
      case 'ticket_status':
      case 'ticket_created':
        return Icons.support_agent_rounded;
      case 'business_approved':
      case 'business_pending':
      case 'business_rejected':
        return Icons.storefront_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'queue_done':
        return AppColors.success;
      case 'queue_serving':
        return AppColors.warning;
      case 'chat_message':
        return AppColors.secondary;
      case 'appointment_booked':
      case 'appointment_status':
      case 'appointment_cancelled':
        return AppColors.primary;
      case 'ticket_admin_reply':
      case 'ticket_status':
      case 'ticket_created':
        return AppColors.info;
      case 'business_approved':
        return AppColors.success;
      case 'business_rejected':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildDismissBackground({required Alignment alignment}) {
    final isLeading = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: isLeading ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeading) const Spacer(),
          const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          const SizedBox(width: 8),
          const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          if (isLeading) const Spacer(),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    if (difference.inDays < 7) return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}';
  }
}