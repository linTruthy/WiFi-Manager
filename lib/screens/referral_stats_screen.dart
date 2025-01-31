import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/referral_stats_provider.dart';

class ReferralStatsScreen extends ConsumerWidget {
  final String referrerId;

  const ReferralStatsScreen({super.key, required this.referrerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralStatsAsync = ref.watch(referralStatsProvider(referrerId));
    final totalReferralsAsync = ref.watch(totalReferralsProvider(referrerId));
    final totalRewardDurationAsync = ref.watch(
      totalRewardDurationProvider(referrerId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Referral Stats')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Referrals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    totalReferralsAsync.when(
                      data:
                          (totalReferrals) => Text(
                            totalReferrals.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      loading: () => const CircularProgressIndicator(),
                      error:
                          (e, __) => SelectableText(
                            e.toString(),
                          ), //const Icon(Icons.error),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Reward Duration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    totalRewardDurationAsync.when(
                      data:
                          (totalRewardDuration) => Text(
                            '${totalRewardDuration.inDays} days',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Icon(Icons.error),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Referral History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            referralStatsAsync.when(
              data:
                  (referralStats) => ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: referralStats.length,
                    itemBuilder: (context, index) {
                      final referral = referralStats[index];
                      final rewardDuration = Duration(
                        milliseconds: referral.rewardDurationMillis,
                      );
                      return ListTile(
                        title: Text(
                          'Referred Customer: ${referral.referredCustomerId}',
                        ),
                        subtitle: Text(
                          'Date: ${DateFormat('MMM d, y').format(referral.referralDate)}\n'
                          'Reward: ${rewardDuration.inDays} days',
                        ),
                      );
                    },
                  ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Icon(Icons.error),
            ),
          ],
        ),
      ),
    );
  }
}
