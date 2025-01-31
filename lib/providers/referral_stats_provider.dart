import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/referral_stats.dart';
import 'database_provider.dart';

final referralStatsProvider =
    FutureProvider.family<List<ReferralStats>, String>((ref, referrerId) async {
      final database = ref.watch(databaseProvider);
      return database.getReferralStats(referrerId);
    });

final totalReferralsProvider = FutureProvider.family<int, String>((
  ref,
  referrerId,
) async {
  final database = ref.watch(databaseProvider);
  return database.getTotalReferrals(referrerId);
});

final totalRewardDurationProvider = FutureProvider.family<Duration, String>((
  ref,
  referrerId,
) async {
  final database = ref.watch(databaseProvider);
  return database.getTotalRewardDuration(referrerId);
});
