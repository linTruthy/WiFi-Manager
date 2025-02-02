import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
//import 'package:workmanager/workmanager.dart';
import 'database/repository/database_repository.dart';
import 'firebase_options.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'app_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'services/app_preferences.dart';
import 'services/subscription_notification_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerWidget {
  final String? initialRoute;

  const MyApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(settings, ref),
      routes: AppRouter.routes,
      title: 'Truthy WiFi Manager',
      initialRoute: initialRoute,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E88E5),
          secondary: Color(0xFF4CAF50),
          surface: Colors.black87,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white.withOpacity(0.1),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black.withOpacity(0.2),
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E88E5),
          secondary: Color(0xFF4CAF50),
          surface: Colors.black87,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white.withOpacity(0.1),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black.withOpacity(0.2),
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      themeMode: ThemeMode.dark,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _configureLocalTimeZone();
  await Future.wait([SubscriptionNotificationService.initialize()]);

  await SubscriptionNotificationService.clearExpiredNotifications();
  // Wait for the user to authenticate
  final auth = FirebaseAuth.instance;
  User? user = auth.currentUser;
  // // Initialize database and schedule notifications
  // final dbRepo = DatabaseRepository();
  // await dbRepo.scheduleNotifications();

  if (user == null) {
    runApp(ProviderScope(child: MyApp(initialRoute: '/login')));
  } else {
    final isFirstTime = await AppPreferences.isFirstTime();
    final initialRoute = isFirstTime ? '/register' : await _getInitialRoute();
    // If the user is authenticated, proceed with Firestore operations
    final dbRepo = DatabaseRepository();
    await dbRepo.scheduleNotifications();
    runApp(ProviderScope(child: MyApp(initialRoute: initialRoute)));
  }
}

Future<String?> _getInitialRoute() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return '/login';
  }
  // Check if the app was launched from a notification

  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    if (payload != null) {
      // Example payload: "customerId=123"
      return '/customer/$payload';
    }
  }
  return '/home'; // Default route
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
