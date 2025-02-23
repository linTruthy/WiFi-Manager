import 'package:firebase_auth/firebase_auth.dart';

import 'database/models/referral_stats.dart';

Duration getRewardDuration(ReferralStats referralStats) {
  return Duration(milliseconds: referralStats.rewardDurationMillis);
}

String generateShareableLink(String customerId, DateTime subscriptionEndDate) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');
  final data = {
    'uid': user.uid,
    'cid': customerId,
  };
  final queryParams = Uri(queryParameters: data).query;
  return "https://truthy-wifi-manager.web.app/customer-share?$queryParams";
}
