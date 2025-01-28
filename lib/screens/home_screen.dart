
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../widgets/expiring_subscriptions_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Manager'),
      ),
      body: Column(
        children: [
          const ExpiringSubscriptionsBanner(),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(8),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                  
                _DashboardCard(
                  title: 'Active Customers',
                  icon: Icons.people,
                  onTap: () => Navigator.pushNamed(context, '/customers'),
                  content: Consumer(
                    builder: (context, ref, child) {
                      final customersAsync = ref.watch(activeCustomersProvider);
                      return customersAsync.when(
                        data: (customers) => Text(
                          customers.length.toString(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                _DashboardCard(
                  title: 'Expiring Soon',
                  icon: Icons.warning,
                  onTap: () => Navigator.pushNamed(context, '/expiring-subscriptions'),
                  content: Consumer(
                    builder: (context, ref, child) {
                      final expiringAsync = ref.watch(expiringCustomersProvider);
                      return expiringAsync.when(
                        data: (customers) => Text(
                          customers.length.toString(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Icon(Icons.error),
                      );
                    },
                  ),
                ),
                _DashboardCard(
                  title: 'Add Customer',
                  icon: Icons.person_add,
                  onTap: () => Navigator.pushNamed(context, '/add-customer'),
                ),
                _DashboardCard(
                  title: 'Recent Payments',
                  icon: Icons.payments,
                  onTap: () => Navigator.pushNamed(context, '/payments'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? content;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(title),
              if (content != null) ...[
                const SizedBox(height: 8),
                content!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
