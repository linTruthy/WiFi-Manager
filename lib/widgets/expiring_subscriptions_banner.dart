// providers/subscription_provider.dart

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
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expiring Subscriptions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('${customers.length} subscriptions expiring soon'),
            ],
          ),
          leading: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pushNamed(context, '/expiring-subscriptions'),
              child: const Text('VIEW ALL'),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
