import 'package:flutter/services.dart';
import '../database/models/customer.dart';

class SubscriptionWidgetService {
  static const platform = MethodChannel('com.truthysystems.wifi/subscription_widget');

  static Future<void> updateWidgetData(
    List<Customer> expiringCustomers,
    int activeCustomersCount,
    double totalRevenue,
  ) async {
    try {
      final List<Map<String, dynamic>> customerData = expiringCustomers.map((customer) {
        return {
          'id': customer.id.toString(),
          'name': customer.name,
          'daysLeft': _formatExpiryTime(customer.subscriptionEnd, customer.subscriptionEnd.difference(DateTime.now()).inDays),
        };
      }).toList();
      await platform.invokeMethod('updateSubscriptionWidget', {
        'expiringCustomers': customerData,
        'activeCustomersCount': activeCustomersCount,
        'totalRevenue': totalRevenue, // Add this to pass revenue
      });
      print('update sent');
    } on PlatformException catch (e) {
      print("Failed to update widget: ${e.message}");
    }
  }

  static String _formatExpiryTime(DateTime subscriptionEnd, int daysUntilExpiry) {
    final now = DateTime.now();
    final difference = subscriptionEnd.difference(now);
    if (daysUntilExpiry > 0) return '$daysUntilExpiry days';
    if (difference.inHours.abs() < 24) return 'Today';
    return 'Expired';
  }
}