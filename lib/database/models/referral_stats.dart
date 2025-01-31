import 'package:isar/isar.dart';

part 'referral_stats.g.dart';

@Collection(inheritance: false)
class ReferralStats {
  Id id = Isar.autoIncrement;
  String referrerId; // ID of the customer who made the referral
  String referredCustomerId; // ID of the customer who was referred
  DateTime referralDate; // Date when the referral was made
  int rewardDurationMillis; // Duration of the reward applied in milliseconds

  ReferralStats({
    required this.referrerId,
    required this.referredCustomerId,
    required this.referralDate,
    required this.rewardDurationMillis,
  });

  // Factory method to create ReferralStats with Duration
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