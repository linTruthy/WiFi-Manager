import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/retention_provider.dart';

class RetentionScreen extends ConsumerStatefulWidget {
  const RetentionScreen({super.key});

  @override
  ConsumerState<RetentionScreen> createState() => _RetentionScreenState();
}

class _RetentionScreenState extends ConsumerState<RetentionScreen> {
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    final retentionAsync = ref.watch(retentionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retention Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select custom date range',
            onPressed: () => _selectDateRange(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
            onPressed: () => ref.refresh(retentionProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(retentionProvider as Refreshable<Future<void>>),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: retentionAsync.when(
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Info
                  if (_selectedRange != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Showing data from ${DateFormat('MMM d, y').format(_selectedRange!.start)} to ${DateFormat('MMM d, y').format(_selectedRange!.end)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    Text(
                      'Last 30 Days',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 16),

                  // Retention Rate
                  _buildMetricCard(
                    context,
                    title: 'Retention Rate',
                    value: '${data['retentionRate'].toStringAsFixed(1)}%',
                    description: 'Percentage of customers retained',
                    color: Colors.green,
                    semanticsLabel:
                        'Retention rate: ${data['retentionRate'].toStringAsFixed(1)} percent',
                  ),
                  const SizedBox(height: 16),

                  // Churn Rate
                  _buildMetricCard(
                    context,
                    title: 'Churn Rate',
                    value: '${data['churnRate'].toStringAsFixed(1)}%',
                    description: 'Percentage of customers lost',
                    color: Colors.red,
                    semanticsLabel:
                        'Churn rate: ${data['churnRate'].toStringAsFixed(1)} percent',
                  ),
                  const SizedBox(height: 16),

                  // New Customers
                  _buildMetricCard(
                    context,
                    title: 'New Customers',
                    value: data['newCustomersLast30Days'].toString(),
                    description: 'Customers added in the last 30 days',
                    color: Colors.blue,
                    semanticsLabel:
                        'New customers in the last 30 days: ${data['newCustomersLast30Days']}',
                  ),
                  const SizedBox(height: 16),

                  // Lost Customers
                  _buildMetricCard(
                    context,
                    title: 'Lost Customers',
                    value: data['lostCustomersLast30Days'].toString(),
                    description: 'Customers lost in the last 30 days',
                    color: Colors.orange,
                    semanticsLabel:
                        'Lost customers in the last 30 days: ${data['lostCustomersLast30Days']}',
                  ),
                  const SizedBox(height: 16),

                  // Active/Inactive Counts
                  _buildMetricCard(
                    context,
                    title: 'Active Customers',
                    value: data['activeCount'].toString(),
                    description: 'Currently active customers',
                    color: Colors.teal,
                    semanticsLabel: 'Active customers: ${data['activeCount']}',
                  ),
                  const SizedBox(height: 16),

                  _buildMetricCard(
                    context,
                    title: 'Inactive Customers',
                    value: data['inactiveCount'].toString(),
                    description: 'Currently inactive customers',
                    color: Colors.grey,
                    semanticsLabel:
                        'Inactive customers: ${data['inactiveCount']}',
                  ),
                  const SizedBox(height: 16),

                  // Navigation to Customer Lists
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Semantics(
                        label: 'View active customers list',
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/customers');
                          },
                          child: const Text('Active List'),
                        ),
                      ),
                      Semantics(
                        label: 'View inactive customers list',
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/inactive-customers');
                          },
                          child: const Text('Inactive List'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => Center(
                child: Semantics(
                  label: 'Loading retention data',
                  child: const CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Failed to load retention data. Please try again.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Retry loading retention data',
                      child: ElevatedButton(
                        onPressed: () => ref.refresh(retentionProvider),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String description,
    required Color color,
    required String semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Card(
        color: Colors.white.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color),
                  ),
                  Tooltip(
                    message: description,
                    child: const Icon(Icons.info_outline, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedRange = picked;
      });
      // TODO: Update retentionProvider to filter by selected range if implemented
    }
  }
}
