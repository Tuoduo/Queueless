import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:queueless/models/business_model.dart';
import 'package:queueless/models/notification_model.dart';
import 'package:queueless/models/user_model.dart';
import 'package:queueless/providers/auth_provider.dart';
import 'package:queueless/providers/business_provider.dart';
import 'package:queueless/providers/notification_provider.dart';
import 'package:queueless/providers/queue_provider.dart';
import 'package:queueless/screens/business/business_home_screen.dart';
import 'package:queueless/screens/shared/notification_center_screen.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider(this._user);

  final UserModel _user;

  @override
  UserModel? get currentUser => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isCustomer => _user.role == UserRole.customer;

  @override
  bool get isBusinessOwner => _user.role == UserRole.businessOwner;

  @override
  bool get isAdmin => _user.role == UserRole.admin;

  @override
  Future<void> logout() async {}
}

class _FakeBusinessProvider extends BusinessProvider {
  @override
  Future<void> loadBusinesses({bool silent = false}) async {}

  @override
  Future<void> loadOwnerBusiness(String ownerId, {bool silent = false}) async {}
}

class _FakeNotificationProvider extends NotificationProvider {
  _FakeNotificationProvider(List<NotificationModel> initialNotifications)
      : _notifications = List<NotificationModel>.from(initialNotifications);

  final List<NotificationModel> _notifications;

  @override
  List<NotificationModel> get notifications => List<NotificationModel>.unmodifiable(_notifications);

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  @override
  Future<void> loadNotifications({bool silent = false}) async {}

  @override
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((item) => item.id == notificationId);
    notifyListeners();
  }

  @override
  Future<void> clearAll() async {
    _notifications.clear();
    notifyListeners();
  }
}

class _FakeQueueProvider extends QueueProvider {
  @override
  void connectSocket() {}

  @override
  void subscribeToQueue(String businessId) {}

  @override
  void unsubscribeFromQueue() {}

  @override
  Future<void> loadQueue(String businessId) async {}

  @override
  Future<void> loadDeliveredOrders(String businessId, {bool silent = false}) async {}
}

Widget _wrapTestApp({
  required AuthProvider authProvider,
  required NotificationProvider notificationProvider,
  required BusinessProvider businessProvider,
  QueueProvider? queueProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
      ChangeNotifierProvider<BusinessProvider>.value(value: businessProvider),
      ChangeNotifierProvider<QueueProvider>.value(value: queueProvider ?? _FakeQueueProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

NotificationModel _notification({
  required String id,
  required String title,
  required String body,
  required String type,
  String? entityType,
  String? entityId,
  Map<String, dynamic>? metadata,
}) {
  return NotificationModel(
    id: id,
    recipientId: 'user-1',
    title: title,
    body: body,
    type: type,
    entityType: entityType,
    entityId: entityId,
    metadata: metadata,
    createdAt: DateTime(2026, 4, 20, 10),
  );
}

Future<void> _pumpNavigation(WidgetTester tester, {Duration duration = const Duration(milliseconds: 450)}) async {
  await tester.pump();
  await tester.pump(duration);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin business notification opens admin shell businesses tab', (tester) async {
    final authProvider = _FakeAuthProvider(
      UserModel(id: 'admin1', name: 'Admin', email: 'admin@queueless.com', phone: '555', role: UserRole.admin),
    );
    final businessProvider = _FakeBusinessProvider();
    final notificationProvider = _FakeNotificationProvider([
      _notification(
        id: 'notif-1',
        title: 'New business awaiting approval',
        body: 'A business is waiting for review.',
        type: 'business_pending',
        entityType: 'business',
        entityId: 'b1',
        metadata: {'businessId': 'b1'},
      ),
    ]);

    await tester.pumpWidget(_wrapTestApp(
      authProvider: authProvider,
      notificationProvider: notificationProvider,
      businessProvider: businessProvider,
      child: const NotificationCenterScreen(),
    ));
    await _pumpNavigation(tester);

    await tester.tap(find.text('New business awaiting approval'));
    await _pumpNavigation(tester);

    expect(find.text('Admin — Businesses'), findsOneWidget);
    expect(find.text('All Businesses'), findsOneWidget);
  });

  testWidgets('owner approval notification opens business shell with bottom navigation', (tester) async {
    final authProvider = _FakeAuthProvider(
      UserModel(id: 'owner1', name: 'Owner Person', email: 'owner@test.com', phone: 'OWNER-PHONE', role: UserRole.businessOwner),
    );
    final businessProvider = _FakeBusinessProvider()
      ..registerBusiness(
        BusinessModel(
          id: 'b1',
          ownerId: 'owner1',
          name: 'Alpha Store',
          description: 'Desc',
          category: BusinessCategory.other,
          serviceType: ServiceType.queue,
          address: 'Address',
          phone: 'BUSINESS-PHONE',
          approvalStatus: 'approved',
        ),
      );
    final notificationProvider = _FakeNotificationProvider([
      _notification(
        id: 'notif-2',
        title: 'Your business was approved',
        body: 'The business is now visible to customers.',
        type: 'business_approved',
        entityType: 'business',
        entityId: 'b1',
        metadata: {'businessId': 'b1'},
      ),
    ]);

    await tester.pumpWidget(_wrapTestApp(
      authProvider: authProvider,
      notificationProvider: notificationProvider,
      businessProvider: businessProvider,
      child: const NotificationCenterScreen(),
    ));
    await _pumpNavigation(tester);

    await tester.tap(find.text('Your business was approved'));
    await _pumpNavigation(tester, duration: const Duration(milliseconds: 700));

    expect(find.text('Alpha Store'), findsAtLeastNWidgets(1));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('Business under review'), findsNothing);
  });

  testWidgets('business approval banner disappears without page switching', (tester) async {
    final authProvider = _FakeAuthProvider(
      UserModel(id: 'owner1', name: 'Owner', email: 'owner@test.com', phone: '555', role: UserRole.businessOwner),
    );
    final businessProvider = _FakeBusinessProvider();
    final notificationProvider = _FakeNotificationProvider(const []);
    final pendingBusiness = BusinessModel(
      id: 'b1',
      ownerId: 'owner1',
      name: 'Alpha Store',
      description: 'Desc',
      category: BusinessCategory.other,
      serviceType: ServiceType.queue,
      address: 'Address',
      phone: '222',
      approvalStatus: 'pending',
      isActive: false,
    );
    businessProvider.registerBusiness(pendingBusiness);

    await tester.pumpWidget(_wrapTestApp(
      authProvider: authProvider,
      notificationProvider: notificationProvider,
      businessProvider: businessProvider,
      child: const BusinessHomeScreen(),
    ));
    await _pumpNavigation(tester);

    expect(find.text('Business under review'), findsOneWidget);

    businessProvider.registerBusiness(
      pendingBusiness.copyWith(approvalStatus: 'approved', isActive: true),
    );
    await _pumpNavigation(tester);

    expect(find.text('Business under review'), findsNothing);
  });

  testWidgets('business settings include owner and business phone fields', (tester) async {
    final authProvider = _FakeAuthProvider(
      UserModel(id: 'owner1', name: 'Owner Person', email: 'owner@test.com', phone: 'OWNER-PHONE', role: UserRole.businessOwner),
    );
    final businessProvider = _FakeBusinessProvider()
      ..registerBusiness(
        BusinessModel(
          id: 'b1',
          ownerId: 'owner1',
          name: 'Alpha Store',
          description: 'Desc',
          category: BusinessCategory.other,
          serviceType: ServiceType.queue,
          address: 'Address',
          phone: 'BUSINESS-PHONE',
          approvalStatus: 'approved',
        ),
      );
    final notificationProvider = _FakeNotificationProvider(const []);

    await tester.pumpWidget(_wrapTestApp(
      authProvider: authProvider,
      notificationProvider: notificationProvider,
      businessProvider: businessProvider,
      child: const BusinessHomeScreen(initialTab: BusinessHomeTab.settings),
    ));
    await _pumpNavigation(tester, duration: const Duration(milliseconds: 700));

    expect(find.text('Owner Person'), findsOneWidget);
    expect(find.text('OWNER-PHONE'), findsOneWidget);
    expect(find.text('BUSINESS-PHONE'), findsOneWidget);
  });
}