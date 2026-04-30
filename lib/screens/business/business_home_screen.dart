import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../models/business_model.dart';
import 'queue_management_screen.dart';
import 'product_management_screen.dart';
import 'appointment_management_screen.dart';
import 'availability_screen.dart';
import 'business_settings_screen.dart';
import 'analytics_screen.dart';
import 'qr_code_screen.dart';
import 'business_reviews_screen.dart';
import 'business_chat_inbox_screen.dart';
import '../../widgets/notification_bell_button.dart';

enum BusinessHomeTab { queue, schedule, bookings, products, reviews, analytics, settings }

class BusinessHomeScreen extends StatefulWidget {
  final BusinessHomeTab initialTab;

  const BusinessHomeScreen({super.key, this.initialTab = BusinessHomeTab.queue});

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _initialTabApplied = false;
  String? _requestedOwnerId;
  String? _missingBusinessRetryOwnerId;

  void _loadOwnerBusinessIfNeeded() {
    final ownerId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    if (ownerId.isEmpty || _requestedOwnerId == ownerId) {
      return;
    }

    _requestedOwnerId = ownerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BusinessProvider>(context, listen: false).loadOwnerBusiness(ownerId);
    });
  }

  void _retryMissingBusinessIfNeeded(String ownerId) {
    if (ownerId.isEmpty || _missingBusinessRetryOwnerId == ownerId) {
      return;
    }

    _missingBusinessRetryOwnerId = ownerId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BusinessProvider>(context, listen: false).loadOwnerBusiness(ownerId, silent: true);
    });
  }

  int _indexForTab(ServiceType serviceType, BusinessHomeTab tab) {
    switch (tab) {
      case BusinessHomeTab.settings:
        return _getScreens(serviceType).length - 1;
      case BusinessHomeTab.analytics:
        return _getScreens(serviceType).length - 2;
      case BusinessHomeTab.reviews:
        return _getScreens(serviceType).length - 3;
      case BusinessHomeTab.products:
        if (serviceType == ServiceType.queue) return 1;
        if (serviceType == ServiceType.appointment) return 2;
        return 3;
      case BusinessHomeTab.bookings:
        if (serviceType == ServiceType.appointment) return 1;
        if (serviceType == ServiceType.both) return 2;
        return 0;
      case BusinessHomeTab.schedule:
        if (serviceType == ServiceType.appointment) return 0;
        if (serviceType == ServiceType.both) return 1;
        return 0;
      case BusinessHomeTab.queue:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerBusinessIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadOwnerBusinessIfNeeded();
  }

  List<Widget> _getScreens(ServiceType serviceType) {
    final List<Widget> screens = [];
    if (serviceType == ServiceType.queue || serviceType == ServiceType.both) {
      screens.add(const QueueManagementScreen());
    }
    if (serviceType == ServiceType.appointment || serviceType == ServiceType.both) {
      screens.add(const AvailabilityScreen());
      screens.add(const AppointmentManagementScreen());
    }
    screens.add(ProductManagementScreen(isService: serviceType == ServiceType.appointment));
    screens.add(const BusinessReviewsScreen());
    screens.add(const AnalyticsScreen());
    screens.add(const BusinessSettingsScreen());
    return screens;
  }

  List<BottomNavigationBarItem> _getNavItems(ServiceType serviceType) {
    final bool isServiceType = serviceType == ServiceType.appointment;
    final List<BottomNavigationBarItem> items = [];
    if (serviceType == ServiceType.queue || serviceType == ServiceType.both) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people_outline),
        activeIcon: Icon(Icons.people),
        label: 'Queue',
      ));
    }
    if (serviceType == ServiceType.appointment || serviceType == ServiceType.both) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month_outlined),
        activeIcon: Icon(Icons.calendar_month),
        label: 'Schedule',
      ));
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today_outlined),
        activeIcon: Icon(Icons.calendar_today),
        label: 'Bookings',
      ));
    }
    items.add(BottomNavigationBarItem(
      icon: Icon(isServiceType ? Icons.design_services_outlined : Icons.inventory_2_outlined),
      activeIcon: Icon(isServiceType ? Icons.design_services : Icons.inventory_2),
      label: isServiceType ? 'Services' : 'Products',
    ));
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.rate_review_outlined),
      activeIcon: Icon(Icons.rate_review),
      label: 'Reviews',
    ));
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.analytics_outlined),
      activeIcon: Icon(Icons.analytics),
      label: 'Analytics',
    ));
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
    ));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);

    final ownerId = auth.currentUser?.id ?? '';
    final business = businessProvider.getBusinessByOwnerId(ownerId);
    if (business != null) {
      _missingBusinessRetryOwnerId = null;
    } else if (!businessProvider.isLoading) {
      _retryMissingBusinessIfNeeded(ownerId);
    }
    final serviceType = business?.serviceType ?? ServiceType.both;

    final screens = _getScreens(serviceType);
    final navItems = _getNavItems(serviceType);

    if (!_initialTabApplied && business != null) {
      _currentIndex = _indexForTab(serviceType, widget.initialTab).clamp(0, screens.length - 1);
      _initialTabApplied = true;
    }

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    // Debug info
    debugPrint('BusinessHomeScreen BUILD: business=${business?.name}, owner=${auth.currentUser?.id}, screens=${screens.length}, currentIdx=$_currentIndex');

    return Scaffold(
      appBar: _buildAppBar(business),
      body: Column(
        children: [
          if (businessProvider.isLoading)
            const LinearProgressIndicator()
          else if (businessProvider.error != null)
            Container(
              color: const Color(0xFFE74C3C),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: ${businessProvider.error}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else if (business != null && business.approvalStatus != 'approved')
            _BusinessApprovalBanner(status: business.approvalStatus),
          Expanded(
            child: business == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.business_center_outlined, size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        const Text('No business found', style: TextStyle(fontSize: 16, color: AppColors.textHint)),
                        const SizedBox(height: 4),
                        Text('Owner ID: $ownerId', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                        Text('Businesses in list: ${businessProvider.businesses.length}', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                      ],
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(_currentIndex),
                      child: screens[_currentIndex],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(navItems),
    );
  }

  PreferredSizeWidget _buildAppBar(BusinessModel? business) {
    return AppBar(
      backgroundColor: AppColors.background,
      toolbarHeight: 72,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                business?.categoryIcon ?? '🏪',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business?.name ?? AppStrings.dashboard,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  business?.categoryDisplayName ?? 'Dashboard',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const NotificationBellButton(),
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: GestureDetector(
            onTap: business == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusinessChatInboxScreen(
                          businessId: business.id,
                          businessName: business.name,
                        ),
                      ),
                    ),
            child: Opacity(
              opacity: business == null ? 0.5 : 1,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.glassGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: AppColors.secondary),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrCodeScreen()),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.glassGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.primary),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: GestureDetector(
            onTap: () {
              debugPrint('Logout button tapped');
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

  Widget _buildBottomNav(List<BottomNavigationBarItem> navItems) {
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
      child: Consumer<BusinessProvider>(
        builder: (context, businessProvider, _) {
          if (businessProvider.error != null) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: ${businessProvider.error}',
                style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: navItems,
          );
        },
      ),
    );
  }
}

class _BusinessApprovalBanner extends StatelessWidget {
  final String status;

  const _BusinessApprovalBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final background = isRejected ? AppColors.error : AppColors.warning;
    final icon = isRejected ? Icons.error_outline_rounded : Icons.pending_actions_rounded;
    final title = isRejected ? 'Business review required' : 'Business under review';
    final message = isRejected
        ? 'Your business is not visible to customers yet. Update the details if needed and ask an admin to review it again.'
        : 'Your business is not visible to customers yet. It will appear after an admin reviews and approves it.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: background.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: background),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: background)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
