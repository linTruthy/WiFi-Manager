import 'database/models/referral_stats.dart';

Duration getRewardDuration(ReferralStats referralStats) {
  return Duration(milliseconds: referralStats.rewardDurationMillis);
}