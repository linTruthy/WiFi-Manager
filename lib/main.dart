import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database/repository/database_repository.dart';
import 'firebase_options.dart';
import 'app_router.dart';
import 'services/notification_service.dart';
import 'services/subscription_notification_service.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(settings, ref),
      routes: AppRouter.routes,
      title: 'Flutter Demo',
      theme: ThemeData(
        //  brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Future.wait([
    NotificationService.initialize(),
    SubscriptionNotificationService.initialize(),
  ]);
  // Initialize database and schedule notifications
  final dbRepo = DatabaseRepository();
  await dbRepo.scheduleNotifications();
  runApp(const ProviderScope(child: MyApp()));
}
