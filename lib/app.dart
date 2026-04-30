import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/queue_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/product_provider.dart';
import 'providers/business_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/discount_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/business/business_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'widgets/loading_widget.dart';

class QueueLessApp extends StatelessWidget {
  const QueueLessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QueueProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => BusinessProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProxyProvider<CartProvider, ProductProvider>(
          create: (_) => ProductProvider(),
          update: (_, cartProvider, productProvider) => productProvider!..attachCartProvider(cartProvider),
        ),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, authProvider, notificationProvider) => notificationProvider!..syncAuth(authProvider),
        ),
      ],
      child: MaterialApp(
        title: 'QueueLess',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: LoadingWidget(message: 'Authenticating...'),
          );
        }

        if (authProvider.isAuthenticated) {
          if (authProvider.isAdmin) {
            return const AdminHomeScreen();
          } else if (authProvider.isCustomer) {
            return const CustomerHomeScreen();
          } else if (authProvider.isBusinessOwner) {
            return const BusinessHomeScreen();
          }
        }
        
        return const LoginScreen();
      },
    );
  }
}
