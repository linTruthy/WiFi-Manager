import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/add_customer_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/expiring_subscriptions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/payments_screen.dart';
import 'services/notification_service.dart';
import 'services/subscription_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await SubscriptionNotificationService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/': (context) => const HomeScreen(),
        '/customers': (context) => const CustomersScreen(),
        '/add-customer': (context) => const AddCustomerScreen(),
        '/payments': (context) => const PaymentsScreen(),
        '/expiring-subscriptions': (context) => const ExpiringSubscriptionsScreen(),
      },
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}