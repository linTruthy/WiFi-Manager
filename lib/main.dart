import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'database/models/customer.dart';
import 'providers/database_provider.dart';
import 'screens/add_customer_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/edit_customer_screen.dart';
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/customer/') ?? false) {
          final customerId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder:
                (context) => FutureBuilder<Customer?>(
                  future: getCustomerById(customerId, ref),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Scaffold(
                        body: Center(child: Text('Customer not found')),
                      );
                    }
                    return CustomerDetailScreen(customer: snapshot.data!);
                  },
                ),
          );
        }
        if (settings.name?.startsWith('/edit-customer/') ?? false) {
          final customerId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder:
                (context) => FutureBuilder<Customer?>(
                  future: getCustomerById(customerId, ref),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Scaffold(
                        body: Center(child: Text('Customer not found')),
                      );
                    }
                    return EditCustomerScreen(customer: snapshot.data!);
                  },
                ),
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const HomeScreen(),
        '/customers': (context) => const CustomersScreen(),
        '/add-customer': (context) => const AddCustomerScreen(),
        '/payments': (context) => const PaymentsScreen(),
        '/expiring-subscriptions':
            (context) => const ExpiringSubscriptionsScreen(),
      },
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }

  Future<Customer?> getCustomerById(String customerId, WidgetRef ref) async {
    final isar = await ref.read(databaseProvider).db;
    var cus = await isar.customers.get(int.parse(customerId));
    return cus;
  }
}
