import 'package:isar/isar.dart';

import 'plan.dart';

part 'customer.g.dart';

@Collection(inheritance: false)
class Customer {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  String name;

  String contact;
  bool isActive;

  @Index(type: IndexType.value)
  String wifiName;
  String currentPassword;

  DateTime subscriptionStart;
  DateTime subscriptionEnd;

  @Enumerated(EnumType.name)
  PlanType planType;

  Customer({
    required this.name,
    required this.contact,
    required this.isActive,
    required this.wifiName,
    required this.currentPassword,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    required this.planType,
  });

  // Generate WiFi name from customer name
  static String generateWifiName(String customerName) {
    // Remove special characters and spaces
    final cleanName = customerName.replaceAll(RegExp(r'[^\w\s]'), '');

    // Split into words
    final words = cleanName.split(' ');

    if (words.length == 1) {
      // Single word - take first 6 characters
      if (words[0].length <= 6) {
        String wifiName = words[0].toUpperCase();

        wifiName +=
            (100 + DateTime.now().millisecondsSinceEpoch % 900).toString();
        return wifiName;
      }
      return words[0].substring(0, words[0].length.clamp(3, 6)).toUpperCase();
    } else {
      // Multiple words - take first character of each word plus numbers
      String wifiName = words.map((word) => word[0]).join();
      // Add numbers if name is too short
      if (wifiName.length < 4) {
        wifiName +=
            (100 + DateTime.now().millisecondsSinceEpoch % 900).toString();
      }
      return wifiName.toUpperCase();
    }
  }
}
