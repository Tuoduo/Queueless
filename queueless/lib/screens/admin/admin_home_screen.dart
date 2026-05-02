import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_businesses_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_tickets_screen.dart';
import '../../widgets/notification_bell_button.dart';

enum AdminHomeTab { dashboard, users, businesses, tickets, settings }

class AdminHomeScreen extends StatefulWidget {
  final AdminHomeTab initialTab;
  final String businessesStatusFilter;

  const AdminHomeScreen({
    super.key,
    this.initialTab = AdminHomeTab.dashboard,
    this.businessesStatusFilter = 'pending',
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedIndexes = <int>{};

  final _labels = const ['Dashboard', 'Users', 'Businesses', 'Tickets', 'Settings'];
  final _icons = const [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.store_rounded,
    Icons.support_agent_rounded,
    Icons.settings_rounded,
  ];

  int _indexForTab(AdminHomeTab tab) {
    switch (tab) {
      case AdminHomeTab.users:
        return 1;
      case AdminHomeTab.businesses:
        return 2;
      case AdminHomeTab.tickets:
        return 3;
      case AdminHomeTab.settings:
        return 4;
      case AdminHomeTab.dashboard:
        return 0;
    }
  }

  List<Widget> _buildScreens() {
    return [
      const AdminDashboardScreen(),
      const AdminUsersScreen(),
      AdminBusinessesScreen(initialStatusFilter: widget.businessesStatusFilter),
      const AdminTicketsScreen(),
      const AdminSettingsScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForTab(widget.initialTab);
    _loadedIndexes.add(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Admin — ${_labels[_currentIndex]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          IconButton(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Provider.of<BusinessProvider>(context, listen: false).reset();
            },
            icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.textHint),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          screens.length,
          (index) => _loadedIndexes.contains(index) ? screens[index] : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5), width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_labels.length, (i) {
                final active = i == _currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentIndex = i;
                      _loadedIndexes.add(i);
                    }),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: active ? 12 : 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icons[i], size: 22, color: active ? AppColors.primary : AppColors.textHint),
                          const SizedBox(height: 2),
                          Text(
                            _labels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                              color: active ? AppColors.primary : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
