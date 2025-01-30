import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';

class ExpiringSubscriptionsBanner extends ConsumerWidget {
  const ExpiringSubscriptionsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);
    return expiringSubscriptions.when(
      data: (customers) {
        if (customers.isEmpty) return const SizedBox.shrink();
        return MaterialBanner(
          backgroundColor: Colors.black87,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expiring Subscriptions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${customers.length} subscriptions expiring soon',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          leading: const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.orange,
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pushNamed(context, '/expiring-subscriptions'),
              child: const Text(
                'VIEW ALL',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
