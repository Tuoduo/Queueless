import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/queue_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/queue_provider.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/business_provider.dart';
import 'business_list_screen.dart';
import 'queue_list_screen.dart';
import 'appointment_list_screen.dart';
import 'purchase_history_screen.dart';
import 'customer_settings_screen.dart';
import '../../widgets/notification_bell_button.dart';

enum CustomerHomeTab { discover, queues, appointments, history, profile }

class CustomerHomeScreen extends StatefulWidget {
  final CustomerHomeTab initialTab;

  const CustomerHomeScreen({super.key, this.initialTab = CustomerHomeTab.discover});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  int _indexForTab(CustomerHomeTab tab) {
    switch (tab) {
      case CustomerHomeTab.queues:
        return 1;
      case CustomerHomeTab.appointments:
        return 2;
      case CustomerHomeTab.history:
        return 3;
      case CustomerHomeTab.profile:
        return 4;
      case CustomerHomeTab.discover:
        return 0;
    }
  }

  List<Widget> _getScreens() {
    return [
      const BusinessListScreen(),
      CustomerQueueListScreen(onExplorePressed: () {
        setState(() => _currentIndex = 0);
      }),
      CustomerAppointmentListScreen(onExplorePressed: () {
        setState(() => _currentIndex = 0);
      }),
      PurchaseHistoryScreen(isActive: _currentIndex == 3),
      const CustomerSettingsScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForTab(widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        Provider.of<AppointmentProvider>(context, listen: false).loadCustomerAppointments(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = _getScreens();
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: _buildAppBar(auth),
      body: Column(
        children: [
          Consumer<QueueProvider>(
            builder: (context, queueProvider, _) {
              final activeQueues = queueProvider.userActiveQueues
                  .where((q) => q.status == QueueEntryStatus.waiting || q.status == QueueEntryStatus.serving)
                  .toList();
              if (activeQueues.isEmpty) return const SizedBox.shrink();
              final first = activeQueues.first;
              final peopleAhead = first.peopleAhead ?? (first.position > 0 ? first.position - 1 : 0);
              final isNext = peopleAhead == 0;
              final barColor = isNext
                  ? AppColors.error.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: barColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isNext ? Icons.flash_on_rounded : Icons.people_outline_rounded,
                      size: 14,
                      color: isNext ? AppColors.error : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isNext
                            ? "It's your turn!"
                            : '$peopleAhead ${peopleAhead == 1 ? 'person' : 'people'} ahead — ${first.businessName ?? ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isNext ? AppColors.error : AppColors.primaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      first.waitTimeEstimate,
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthProvider auth) {
    return AppBar(
      backgroundColor: AppColors.background,
      toolbarHeight: 72,
      title: Row(
        children: [
          if (_currentIndex == 0) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.flash_on_rounded, size: 22, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentIndex == 0
                  ? Column(
                      key: const ValueKey('discover'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => AppColors.heroGradient.createShader(bounds),
                          child: Text(
                            'Hello, ${auth.currentUser?.name.split(' ').first ?? 'there'}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      key: ValueKey('title_$_currentIndex'),
                      _getAppBarTitle(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
      actions: [
        const NotificationBellButton(),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: GestureDetector(
            onTap: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Provider.of<BusinessProvider>(context, listen: false).reset();
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.glassGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.textHint),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5), width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.explore_outlined, Icons.explore, 'Discover'),
              _buildNavItem(1, Icons.people_outline, Icons.people, 'Queues',
                badgeBuilder: () {
                  return Consumer<QueueProvider>(
                    builder: (context, qp, _) {
                      final count = qp.userActiveQueues.length;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  );
                },
              ),
              _buildNavItem(2, Icons.calendar_today_outlined, Icons.calendar_today, 'Appointments',
                badgeBuilder: () {
                  return Consumer<AppointmentProvider>(
                    builder: (context, ap, _) {
                      final count = ap.activeCustomerAppointments.length;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  );
                },
              ),
              _buildNavItem(3, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'History'),
              _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {Widget Function()? badgeBuilder}) {
    final isActive = _currentIndex == index;

    Widget iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Icon(
        isActive ? activeIcon : icon,
        key: ValueKey('nav_${index}_$isActive'),
        color: isActive ? AppColors.primary : AppColors.textHint,
        size: 24,
      ),
    );

    if (badgeBuilder != null) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -4,
            child: badgeBuilder(),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                color: isActive ? AppColors.primary : AppColors.textHint,
              ),
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Discover';
      case 1:
        return 'My Queues';
      case 2:
        return 'My Appointments';
      case 3:
        return 'Purchase History';
      case 4:
        return 'Profile';
      default:
        return AppStrings.appName;
    }
  }
}
