import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/notification_schedule_provider.dart';

class ScheduledRemindersScreen extends ConsumerWidget {
  const ScheduledRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledNotificationsAsync = ref.watch(
      scheduledNotificationsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Reminders')),
      body: scheduledNotificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No scheduled reminders.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                child: ListTile(
                  title: Text(notification['customerName']??''),
                  subtitle: Text(
                    'Scheduled for: ${DateFormat('MMM d, y - h:mm a').format(notification['notificationTime']??DateTime.now())}\n'
                    'Message: ${notification['message']??''}',
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // Suggested code may be subject to a license. Learn more: ~LicenseLog:2281224614.
        error:
            (e, stackTrace) => Center(
              child: SelectableText('Failed to load reminders. $e \n $stackTrace'),
            ),
      ),
    );
  }
}
