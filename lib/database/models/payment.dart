import 'package:isar/isar.dart';
import 'plan.dart';

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

  @Index(type: IndexType.value)
  DateTime lastModified;

  Payment({
    required this.paymentDate,
    required this.amount,
    required this.customerId,
    required this.planType,
    this.isConfirmed = false,
  }) : lastModified = DateTime.now();

  // Convert Payment instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentDate': paymentDate.toIso8601String(),
      'amount': amount,
      'customerId': customerId,
      'planType': planType.name,
      'isConfirmed': isConfirmed,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  // Create Payment instance from JSON
  static Payment fromJson(Map<String, dynamic> json) {
    return Payment(
        paymentDate: DateTime.parse(json['paymentDate'] as String),
        amount: json['amount'] as double,
        customerId: json['customerId'] as String,
        planType: PlanType.values.firstWhere(
          (e) => e.name == json['planType'],
          orElse: () => PlanType.daily,
        ),
        isConfirmed: json['isConfirmed'] as bool,
      )
      ..id = json['id'] as int
      ..lastModified = DateTime.parse(json['lastModified'] as String);
  }

  // Copy with method for updates
  Payment copyWith({
    DateTime? paymentDate,
    double? amount,
    String? customerId,
    PlanType? planType,
    bool? isConfirmed,
  }) {
    return Payment(
        paymentDate: paymentDate ?? this.paymentDate,
        amount: amount ?? this.amount,
        customerId: customerId ?? this.customerId,
        planType: planType ?? this.planType,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      )
      ..id = id
      ..lastModified = DateTime.now();
  }
}
