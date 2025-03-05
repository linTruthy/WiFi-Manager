import 'package:shared_preferences/shared_preferences.dart';

enum PlanType { daily, weekly, monthly }

class Plan {
  String id; // Changed from Id to String
  PlanType type;
  double price;
  int durationInDays;

  Plan({
    required this.type,
    required this.price,
    required this.durationInDays,
  }) : id = ''; // Initialize as empty; will be set when saving

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'price': price,
      'durationInDays': durationInDays,
    };
  }

  static Plan fromJson(String id, Map<String, dynamic> json) {
    return Plan(
      type: PlanType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PlanType.daily,
      ),
      price: json['price'] as double,
      durationInDays: json['durationInDays'] as int,
    )..id = id;
  }

  Future<List<Plan>> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      Plan(
        type: PlanType.daily,
        price: prefs.getDouble('dailyPrice') ?? 1000.0,
        durationInDays: 1,
      ),
      Plan(
        type: PlanType.weekly,
        price: prefs.getDouble('weeklyPrice') ?? 5000.0,
        durationInDays: 7,
      ),
      Plan(
        type: PlanType.monthly,
        price: prefs.getDouble('monthlyPrice') ?? 15000.0,
        durationInDays: 30,
      ),
    ];
  }
}
// extension StringExtension on String {
//   dynamic let(Function(String) fn) => fn(this);
// }