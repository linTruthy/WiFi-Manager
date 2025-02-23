import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truthy_wifi_manager/screens/customer_share_view.dart';
import 'database/models/customer.dart';
import 'providers/database_provider.dart';
import 'screens/add_customer_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/downtime_input_screen.dart';
import 'screens/edit_customer_screen.dart';
import 'screens/expiring_subscriptions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inactive_customers_screen.dart';
import 'screens/login_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/settings_screen.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(
      RouteSettings settings, WidgetRef ref) {
    return switch (settings.name) {
      '/login' => MaterialPageRoute(builder: (_) => const LoginScreen()),
      '/register' => MaterialPageRoute(builder: (_) => const RegisterScreen()),
      '/downtime-input' =>
        MaterialPageRoute(builder: (_) => const DowntimeInputScreen()),
      final name when name?.startsWith('/customer/') ?? false =>
        MaterialPageRoute(
          builder: (context) =>
              _buildCustomerDetailScreen(settings.name!.split('/').last, ref),
        ),
      final name when name?.startsWith('/edit-customer/') ?? false =>
        MaterialPageRoute(
          builder: (context) =>
              _buildEditCustomerScreen(settings.name!.split('/').last, ref),
        ),
      _ => null,
    };
  }

  static Widget _buildCustomerDetailScreen(String customerId, WidgetRef ref) {
    return FutureBuilder<Customer?>(
      future: _getCustomerById(customerId, ref),
      builder: (context, snapshot) {
        return buildLoadingOrError(
          snapshot,
          (data) => CustomerDetailScreen(customer: data),
        );
      },
    );
  }

  static Widget _buildEditCustomerScreen(String customerId, WidgetRef ref) {
    return FutureBuilder<Customer?>(
      future: _getCustomerById(customerId, ref),
      builder: (context, snapshot) {
        return buildLoadingOrError(
          snapshot,
          (data) => EditCustomerScreen(customer: data),
        );
      },
    );
  }

  static Widget buildLoadingOrError(
      AsyncSnapshot<Customer?> snapshot, Widget Function(Customer) onData) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!snapshot.hasData || snapshot.data == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }
    return onData(snapshot.data!);
  }

  static Future<Customer?> _getCustomerById(
      String customerId, WidgetRef ref) async {
    final database = ref.read(databaseProvider);
    final doc = await database.firestore
        .collection(database.getUserCollectionPath('customers'))
        .doc(customerId)
        .get();
    return doc.exists ? Customer.fromJson(doc.id, doc.data()!) : null;
  }

  static final routes = {
    '/': (context) => const LoginScreen(),
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/customers': (context) => const CustomersScreen(),
    '/add-customer': (context) => const AddCustomerScreen(),
    '/inactive-customers': (context) => const InactiveCustomersScreen(),
    '/payments': (context) => const PaymentsScreen(),
    '/expiring-subscriptions': (context) => const ExpiringSubscriptionsScreen(),
    '/home': (context) => const HomeScreen(),
    '/downtime-input': (context) => const DowntimeInputScreen(),
    '/customer-share': (context) => const CustomerShareView(),
    '/settings': (context) => const SettingsScreen(),
  };
}
