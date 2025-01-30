import 'dart:async';

import '../database/repository/database_repository.dart';

class NotificationScheduler {
  final DatabaseRepository _repository;
  Timer? _schedulingTimer;

  NotificationScheduler(this._repository) {
    // Schedule initial check
    _scheduleNotificationCheck();

    // Set up periodic checks
    _schedulingTimer = Timer.periodic(
      const Duration(hours: 12),
      (_) => _scheduleNotificationCheck(),
    );
  }

  Future<void> _scheduleNotificationCheck() async {
    try {
      await _repository.scheduleNotifications();
    } catch (e) {
      print('Error scheduling notifications: $e');
      // Implement proper error logging here
    }
  }

  void dispose() {
    _schedulingTimer?.cancel();
  }
}
