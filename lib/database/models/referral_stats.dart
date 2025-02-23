
class ReferralStats {
  String id; // Changed from Id to String
  String referrerId;
  String referredCustomerId;
  DateTime referralDate;
  int rewardDurationMillis;

  ReferralStats({
    required this.referrerId,
    required this.referredCustomerId,
    required this.referralDate,
    required this.rewardDurationMillis,
  }) : id = ''; // Initialize as empty; will be set when saving

  Map<String, dynamic> toJson() {
    return {
      'referrerId': referrerId,
      'referredCustomerId': referredCustomerId,
      'referralDate': referralDate.toIso8601String(),
      'rewardDurationMillis': rewardDurationMillis,
    };
  }

  static ReferralStats fromJson(String id, Map<String, dynamic> json) {
    return ReferralStats(
      referrerId: json['referrerId'] as String,
      referredCustomerId: json['referredCustomerId'] as String,
      referralDate: DateTime.parse(json['referralDate'] as String),
      rewardDurationMillis: json['rewardDurationMillis'] as int,
    )..id = id;
  }

  factory ReferralStats.fromDuration({
    required String referrerId,
    required String referredCustomerId,
    required DateTime referralDate,
    required Duration rewardDuration,
  }) {
    return ReferralStats(
      referrerId: referrerId,
      referredCustomerId: referredCustomerId,
      referralDate: referralDate,
      rewardDurationMillis: rewardDuration.inMilliseconds,
    );
  }
}