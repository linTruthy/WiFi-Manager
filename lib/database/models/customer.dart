import 'package:isar/isar.dart';
import 'package:myapp/database/models/plan.dart';

part 'customer.g.dart';

@Collection(inheritance: false)
class Customer {
 Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  String name;

  String contact;
  bool isActive;
  String currentPassword;
  DateTime subscriptionStart;
  DateTime subscriptionEnd;

  @Enumerated(EnumType.name)
  PlanType planType;

  Customer({
   
    required this.name,
    required this.contact,
    required this.isActive,
    required this.currentPassword,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    required this.planType,
  });
}
