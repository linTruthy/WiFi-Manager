import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_scheduler.dart';
import '../services/subscription_notification_service.dart';
import 'database_provider.dart';

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(ref.watch(databaseProvider));
});
final scheduledNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SubscriptionNotificationService.getScheduledNotifications();
});