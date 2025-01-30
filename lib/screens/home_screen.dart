import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../services/subscription_notification_service.dart';
import '../widgets/expiring_subscriptions_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationSchedulerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truthy WiFi Manager'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const ExpiringSubscriptionsBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _DashboardCard(
                    title: 'Active Customers',
                    icon: CupertinoIcons.person_2,
                    onTap: () => Navigator.pushNamed(context, '/customers'),
                    content: Consumer(
                      builder: (context, ref, child) {
                        final customersAsync = ref.watch(
                          activeCustomersProvider,
                        );
                        return customersAsync.when(
                          data:
                              (customers) => Text(
                                customers.length.toString(),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                  _DashboardCard(
                    title: 'Expiring Soon',
                    icon: CupertinoIcons.exclamationmark_triangle,
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/expiring-subscriptions',
                        ),
                    content: Consumer(
                      builder: (context, ref, child) {
                        final expiringAsync = ref.watch(
                          expiringCustomersProvider,
                        );
                        return expiringAsync.when(
                          data:
                              (customers) => Text(
                                customers.length.toString(),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                  _DashboardCard(
                    title: 'Add Customer',
                    icon: CupertinoIcons.person_add,
                    onTap: () => Navigator.pushNamed(context, '/add-customer'),
                  ),
                  _DashboardCard(
                    title: 'Recent Payments',
                    icon: CupertinoIcons.money_dollar,
                    onTap: () => Navigator.pushNamed(context, '/payments'),
                  ),
                  if (kDebugMode)
                    _DashboardCard(
                      title: 'Test Notifications',
                      icon: CupertinoIcons.settings,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TestNotificationWidget(),
                            ),
                          ),
                    ),
                  if (kDebugMode)
                    _DashboardCard(
                      title: 'Delete All',
                      icon: CupertinoIcons.delete,
                      onTap:
                          () => ref.read(databaseProvider).deleteAllRecords(),
                    ),
                ],
              ),
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.black87, Colors.black12],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (content != null) ...[const SizedBox(height: 8), content!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
