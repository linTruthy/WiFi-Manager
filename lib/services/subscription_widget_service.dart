import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wifi_manager/database/models/customer.dart';

class SubscriptionWidgetService {
  static const platform = MethodChannel(
    'com.truthysystems.wifi/subscription_widget',
  );

  static Future<void> updateWidgetData(
    List<Customer> expiringCustomers,
    int activeCustomersCount,
  ) async {
    try {
      final List<Map<String, dynamic>> customerData =
          expiringCustomers.map((customer) {
            return {
              'name': customer.name,
              'daysLeft': _formatExpiryTime(
                customer.subscriptionEnd,
                customer.subscriptionEnd.difference(DateTime.now()).inDays,
              ),
            };
          }).toList();

      await platform.invokeMethod('updateSubscriptionWidget', {
        'expiringCustomers': customerData,
        'activeCustomersCount': activeCustomersCount,
      });
    } on PlatformException catch (e) {
      print("Failed to update widget: ${e.message}");
    }
  }

  static String _formatExpiryTime(
    DateTime subscriptionEnd,
    int daysUntilExpiry,
  ) {
    final now = DateTime.now();
    final difference = subscriptionEnd.difference(now);

    if (daysUntilExpiry > 0) {
      // Positive days - standard display
      return DateFormat('MMM d, y').format(subscriptionEnd);
    } else if (difference.inHours.abs() < 24) {
      // Less than a day (hours)
      final hours = difference.inHours.abs();
      final prefix = difference.isNegative ? 'Expired' : 'Expires';
      return '$prefix in $hours hour${hours != 1 ? 's' : ''}';
    } else if (difference.inMinutes.abs() < 60) {
      // Less than an hour (minutes)
      final minutes = difference.inMinutes.abs();
      final prefix = difference.isNegative ? 'Expired' : 'Expires';
      return '$prefix in $minutes minute${minutes != 1 ? 's' : ''}';
    } else {
      // More than a day past expiration
      final expiredDays = (-daysUntilExpiry).abs();
      return 'Expired $expiredDays day${expiredDays != 1 ? 's' : ''} ago';
    }
  }
}
