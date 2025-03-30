import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/notification_schedule_provider.dart';

class ScheduledRemindersScreen extends ConsumerWidget {
  const ScheduledRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledNotificationsAsync =
        ref.watch(scheduledNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh reminders',
            onPressed: () => ref.refresh(scheduledNotificationsProvider),
          ),
        ],
      ),
      body: scheduledNotificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildNotificationsList(context, notifications);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stackTrace) => _buildErrorState(context, e, stackTrace, ref),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No scheduled reminders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Reminders for expiring subscriptions will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/customers'),
            icon: const Icon(Icons.people),
            label: const Text('View Customers'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error,
      StackTrace stackTrace, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load reminders',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.red[400],
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[300],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(scheduledNotificationsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
      BuildContext context, List<Map<String, dynamic>> notifications) {
    // Sort notifications by time
    notifications.sort((a, b) => (a['notificationTime'] as DateTime)
        .compareTo(b['notificationTime'] as DateTime));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _buildNotificationCard(context, notifications[index]);
      },
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, Map<String, dynamic> notification) {
    final notificationTime = notification['notificationTime'] as DateTime;
    final now = DateTime.now();
    final isUpcoming = notificationTime.isAfter(now);
    final timeDifference = notificationTime.difference(now);
    final theme = Theme.of(context);

    // Format time difference
    String timeStatus;
    if (isUpcoming) {
      if (timeDifference.inDays > 0) {
        timeStatus =
            'In ${timeDifference.inDays} day${timeDifference.inDays != 1 ? 's' : ''}';
      } else if (timeDifference.inHours > 0) {
        timeStatus =
            'In ${timeDifference.inHours} hour${timeDifference.inHours != 1 ? 's' : ''}';
      } else {
        timeStatus =
            'In ${timeDifference.inMinutes} minute${timeDifference.inMinutes != 1 ? 's' : ''}';
      }
    } else {
      timeStatus = 'Sent';
    }

    return Semantics(
      label: 'Reminder for ${notification['customerName']} ${timeStatus}',
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isUpcoming
                ? theme.colorScheme.primary.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: isUpcoming
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isUpcoming ? 'Upcoming Reminder' : 'Sent Reminder',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUpcoming
                            ? theme.colorScheme.primary
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUpcoming
                            ? theme.colorScheme.primary.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        timeStatus,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isUpcoming
                              ? theme.colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isUpcoming
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        child: Text(
                          notification['customerName'] != null &&
                                  (notification['customerName'] as String)
                                      .isNotEmpty
                              ? (notification['customerName'] as String)[0]
                                  .toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: isUpcoming
                                ? theme.colorScheme.primary
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification['customerName'] as String? ??
                                  'Unknown Customer',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification['planType'] as String? ??
                                  'Unknown Plan',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Details',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context,
                          'Scheduled For',
                          DateFormat('MMM d, y - h:mm a').format(
                              notification['notificationTime'] as DateTime),
                          Icons.access_time,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context,
                          'Subscription End',
                          DateFormat('MMM d, y - h:mm a').format(
                              notification['subscriptionEnd'] as DateTime),
                          Icons.event,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context,
                          'Message',
                          notification['message'] as String? ?? 'No message',
                          Icons.message,
                        ),
                      ],
                    ),
                  ),
                  if (isUpcoming) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Cancel Reminder'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // This would require implementing a cancel function
                            // in the SubscriptionNotificationService
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Cancel feature not implemented')));
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
