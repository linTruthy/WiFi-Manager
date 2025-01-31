import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_manager/database/models/customer.dart';
import 'package:wifi_manager/providers/database_provider.dart';
import 'package:wifi_manager/screens/add_customer_screen.dart';
import 'package:wifi_manager/screens/customer_detail_screen.dart';
import 'package:wifi_manager/screens/customers_screen.dart';
import 'package:wifi_manager/screens/edit_customer_screen.dart';
import 'package:wifi_manager/screens/expiring_subscriptions_screen.dart';
import 'package:wifi_manager/screens/home_screen.dart';
import 'package:wifi_manager/screens/payments_screen.dart';

import 'screens/inactive_customers_screen.dart';
import 'screens/login_screen.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
    WidgetRef ref,
  ) {
    // Extract route generation logic
    return switch (settings.name) {
      '/login' => MaterialPageRoute(builder: (_) => const LoginScreen()),
      '/register' => MaterialPageRoute(builder: (_) => const RegisterScreen()),

      final name when name?.startsWith('/customer/') ?? false =>
        MaterialPageRoute(
          builder:
              (context) => _buildCustomerDetailScreen(
                settings.name!.split('/').last,
                ref,
              ),
        ),
      final name when name?.startsWith('/edit-customer/') ?? false =>
        MaterialPageRoute(
          builder:
              (context) =>
                  _buildEditCustomerScreen(settings.name!.split('/').last, ref),
        ),
      _ => null,
    };
  }

  // Separate widget builders to reduce complexity
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

  // Reusable loading/error handler
  static Widget buildLoadingOrError(
    AsyncSnapshot<Customer?> snapshot,
    Widget Function(Customer) onData,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!snapshot.hasData || snapshot.data == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }
    return onData(snapshot.data!);
  }

  // Optimize database access
  static Future<Customer?> _getCustomerById(
    String customerId,
    WidgetRef ref,
  ) async {
    final isar = await ref.read(databaseProvider).db;
    return isar.customers.get(int.parse(customerId));
  }

  // Define static routes
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
  };
}
