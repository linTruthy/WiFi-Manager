import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database/models/customer.dart';
import 'database/repository/database_repository.dart';
import 'firebase_options.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'app_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/auth_service.dart';
import 'package:in_app_update/in_app_update.dart';
import 'services/notification_scheduler.dart';
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
      //home: kIsWeb ? const CustomerShareView() : null,
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.1),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black.withOpacity(0.2),
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          headlineMedium:
              TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge:
              TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Color(0xFF1A73E8), // Same blue for consistency
        scaffoldBackgroundColor: Color(0xFF121212), // Deep dark background
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF1A73E8),
          secondary: Color(0xFFBB86FC), // Lighter purple for dark mode
          surface: Color(0xFF1E1E1E),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.1),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFFE0E0E0),
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFBB86FC),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1A73E8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  String initialRoute;
  if (kIsWeb) {
    final uri = Uri.parse(PlatformDispatcher.instance.defaultRouteName);
    if (uri.path == '/customer-share') {
      initialRoute = uri.toString(); // Preserve query parameters
    } else {
      initialRoute = '/customer-share'; // Default for web
    }
  } else {
    await _configureLocalTimeZone();
    await SubscriptionNotificationService.initialize();
    await MobileAds.instance.initialize();
    NotificationScheduler();
    await SubscriptionNotificationService.clearExpiredNotifications();
    final authService = AuthService();
    initialRoute = await authService.getInitialRoute();
    // Check for updates on app start (Android only)
    if (Platform.isAndroid) {
      await _checkForUpdateOnStart();
    }
    if (initialRoute == '/home') {
      final dbRepo = DatabaseRepository();
      final snapshot = await dbRepo.firestore
          .collection(dbRepo.getUserCollectionPath('customers'))
          .where('isActive', isEqualTo: true)
          .get();
      final customers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();
      await SubscriptionNotificationService.scheduleExpirationNotifications(
          customers);
    }
  }
  runApp(ProviderScope(child: MyApp(initialRoute: initialRoute)));
}

Future<void> _checkForUpdateOnStart() async {
  try {
    final updateInfo = await InAppUpdate.checkForUpdate();
    if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
      if (updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        // Note: Flexible update completion would typically be handled later
      }
    }
  } catch (e) {
    print('Error checking for update on start: $e');
  }
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) return;
  tz.initializeTimeZones();
  if (Platform.isWindows) return;
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));
}
