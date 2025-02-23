
// import 'package:isar/isar.dart';

// import 'customer.dart';
// part 'plan.g.dart';

// // enum PlanType {
// //   daily,
// //   weekly,
// //   monthly
// // }


// @Collection()
// class Plan {
//   Id id = Isar.autoIncrement;

//   @Enumerated(EnumType.name)
//   PlanType type;
  
//   double price;
//   int durationInDays;
  
//   Plan({
   
//     required this.type,
//     required this.price,
//     required this.durationInDays,
//   });
// }

enum PlanType {
  daily,
  weekly,
  monthly
}

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
}