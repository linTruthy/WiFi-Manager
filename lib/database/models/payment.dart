import 'package:isar/isar.dart';
import 'package:myapp/database/models/plan.dart';
part 'payment.g.dart';

@Collection(inheritance: false)
class Payment {
 Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  DateTime paymentDate;

  double amount;
  String customerId;
  @Enumerated(EnumType.name)
  PlanType planType;
  bool isConfirmed;

  Payment({
   
    required this.paymentDate,
    required this.amount,
    required this.customerId,
    required this.planType,
    this.isConfirmed = false,
  });
}
