import 'package:riverpod/riverpod.dart';

import '../services/notification_service.dart';

final notificationProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
