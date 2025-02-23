import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/retention_provider.dart';

class RetentionScreen extends ConsumerWidget {
  const RetentionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retentionData = ref.watch(retentionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retention Dashboard'),
      ),
      body: retentionData.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(
                'Retention Rate',
                '${data['retentionRate'].toStringAsFixed(1)}%',
                'Percentage of customers still active',
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Churn Rate',
                '${data['churnRate'].toStringAsFixed(1)}%',
                'Percentage of customers lost',
                Colors.red,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Active Customers',
                data['activeCount'].toString(),
                'Total active subscriptions',
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Inactive Customers',
                data['inactiveCount'].toString(),
                'Total inactive subscriptions',
                Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                'Last 30 Days',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              _buildSummaryCard(
                'New Customers',
                data['newCustomersLast30Days'].toString(),
                'Customers added in last 30 days',
                Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Lost Customers',
                data['lostCustomersLast30Days'].toString(),
                'Customers lost in last 30 days',
                Colors.orange,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, Color color) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
