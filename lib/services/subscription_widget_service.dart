import 'package:flutter/services.dart';
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
              'daysLeft':
                  customer.subscriptionEnd.difference(DateTime.now()).inDays,
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
}
