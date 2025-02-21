

import 'dart:convert';

import 'database/models/referral_stats.dart';

Duration getRewardDuration(ReferralStats referralStats) {
  return Duration(milliseconds: referralStats.rewardDurationMillis);
}



String generateShareableLink(String customerId, DateTime subscriptionEndDate) {
  final encodedCustomerId = base64Url.encode(utf8.encode(customerId));
  final data = {
    'cid': encodedCustomerId,
    'exp': subscriptionEndDate.millisecondsSinceEpoch.toString(),
  };
  final queryParams = Uri(queryParameters: data).query;
  return "https://your-domain.com/customer-share?$queryParams";
}

String? decodeCustomerId(String? encodedId) {
  if (encodedId == null) return null;
  try {
    return utf8.decode(base64Url.decode(encodedId));
  } catch (e) {
    print('Error decoding customer ID: $e');
    return null;
  }
}



