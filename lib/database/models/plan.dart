
import 'package:isar/isar.dart';
part 'plan.g.dart';

enum PlanType {
  daily,
  weekly,
  monthly
}


@Collection()
class Plan {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  PlanType type;
  
  double price;
  int durationInDays;
  
  Plan({
   
    required this.type,
    required this.price,
    required this.durationInDays,
  });
}

