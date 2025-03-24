import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:truthy_wifi_manager/my_app.dart';
//import 'package:workmanager/workmanager.dart';
import 'database/repository/database_repository.dart';
import 'firebase_options.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'services/auth_service.dart';
import 'services/subscription_notification_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _configureLocalTimeZone();
  await Future.wait([SubscriptionNotificationService.initialize()]);
  await MobileAds.instance.initialize();
  await SubscriptionNotificationService.clearExpiredNotifications();
  final authService = AuthService();
  final initialRoute = await authService.getInitialRoute();

  if (initialRoute == '/home') {
    final dbRepo = DatabaseRepository();
    await dbRepo.scheduleNotifications();
  }
  runApp(ProviderScope(child: MyApp(initialRoute: initialRoute)));
}


Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  if (Platform.isWindows) {
    return;
  }
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
}
