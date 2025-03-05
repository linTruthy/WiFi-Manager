import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truthy_wifi_manager/screens/customer_share_view.dart';
import 'package:truthy_wifi_manager/screens/retention_screen.dart';
import 'database/models/customer.dart';
import 'providers/database_provider.dart';
import 'screens/about_screen.dart';
import 'screens/add_customer_screen.dart';
import 'screens/billing_cycle_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/downtime_input_screen.dart';
import 'screens/edit_customer_screen.dart';
import 'screens/expiring_subscriptions_screen.dart';
import 'screens/home_screen.dart';
import 'screens/how_to_screen.dart';
import 'screens/inactive_customers_screen.dart';
import 'screens/login_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/scheduled_reminders_screen.dart';
import 'screens/settings_screen.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(
      RouteSettings settings, WidgetRef ref) {
    final uri = Uri.parse(settings.name ?? '/');
    final path = uri.path;
    switch (path) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case '/downtime-input':
        return MaterialPageRoute(builder: (_) => const DowntimeInputScreen());
      case '/customer-share':
        return MaterialPageRoute(builder: (_) => const CustomerShareView());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/scheduled-reminders':
        return MaterialPageRoute(
            builder: (_) => const ScheduledRemindersScreen());
      case '/billing-cycles':
        return MaterialPageRoute(builder: (_) => const BillingCycleScreen());
      case '/retention':
        return MaterialPageRoute(builder: (_) => const RetentionScreen());
      case '/about':
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case '/how-to':
        return MaterialPageRoute(builder: (_) => const HowToScreen());
      default:
        if (path.startsWith('/customer/')) {
          final customerId = path.split('/').last;
          final customer = settings.arguments as Customer?;
          if (customer != null && customer.id == customerId) {
            return MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(customer: customer),
            );
          }
          return MaterialPageRoute(
            builder: (_) => _buildCustomerDetailScreen(customerId, ref),
          );
        } else if (path.startsWith('/edit-customer/')) {
          final customerId = path.split('/').last;
          final customer = settings.arguments as Customer?;
          if (customer != null && customer.id == customerId) {
            return MaterialPageRoute(
              builder: (_) => EditCustomerScreen(customer: customer),
            );
          }
          return MaterialPageRoute(
            builder: (_) => _buildEditCustomerScreen(customerId, ref),
          );
        }
        return null; // Let routes table handle static routes
    }
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
    '/billing-cycles': (context) => const BillingCycleScreen(),
    '/retention': (context) => const RetentionScreen(),
    '/about': (context) => const AboutScreen(),
    '/how-to': (context) => const HowToScreen(),
    '/scheduled-reminders': (context) => const ScheduledRemindersScreen(),
  };
}
