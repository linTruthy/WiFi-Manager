import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_manager/services/app_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _persistentLoginKey = 'persistentLogin';
  static const String _userEmailKey = 'userEmail';
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithPersistence(
    String email,
    String password,
    bool rememberMe,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_persistentLoginKey, true);
        await prefs.setString(_userEmailKey, email);
      }

      return userCredential.user;
    } catch (e) {
      return null;
    }
  }

  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove(_persistentLoginKey);
    await prefs.remove(_userEmailKey);
    await _auth.signOut();
  }

  Future<bool> authenticateWithBiometrics() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();

    if (!canCheckBiometrics || !isDeviceSupported) {
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  getInitialRoute() async {
    // First check if app was launched from notification
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await FlutterLocalNotificationsPlugin()
            .getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          notificationAppLaunchDetails!.notificationResponse?.payload;
      if (payload != null) {
        // Verify auth state before returning notification route
        if (await isPersistentLoginValid()) {
          return '/customer/$payload';
        }
      }
    }

    // Check first time launch
    final isFirstTime = await AppPreferences.isFirstTime();
    if (isFirstTime) {
      return '/register';
    }

    // Check persistent login
    if (await isPersistentLoginValid()) {
      return '/home';
    }

    // Default to login if no other conditions are met
    return '/login';
  }

  Future<bool> isPersistentLoginValid() async {
    final prefs = await SharedPreferences.getInstance();
    final isPersistent = prefs.getBool(_persistentLoginKey) ?? false;
    final storedEmail = prefs.getString(_userEmailKey);

    if (!isPersistent || storedEmail == null) return false;

    // Verify if the stored user matches current Firebase user
    final currentUser = _auth.currentUser;
    return currentUser != null && currentUser.email == storedEmail;
  }
}
