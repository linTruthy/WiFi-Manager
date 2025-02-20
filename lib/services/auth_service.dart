import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  final User? user;
  final String? error;
  final bool requiresVerification;

  AuthResult({
    this.user,
    this.error,
    this.requiresVerification = false,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _persistentLoginKey = 'persistentLogin';
  static const String _userEmailKey = 'userEmail';
  static const String _sessionTimeKey = 'sessionStartTime';
  static const Duration _sessionTimeout = Duration(hours: 24);

  // Stream to handle session state
  final _authStateController = StreamController<User?>.broadcast();
  Stream<User?> get authStateChanges => _authStateController.stream;

  User? get currentUser => _auth.currentUser;

  // Password validation
  bool isPasswordStrong(String password) {
    return password.length >= 8 && // Minimum length
        RegExp(r'[A-Z]').hasMatch(password) && // Has uppercase
        RegExp(r'[a-z]').hasMatch(password) && // Has lowercase
        RegExp(r'[0-9]').hasMatch(password) && // Has numbers
        RegExp(r'[!@#$%^&*(),.?":{}|<>]')
            .hasMatch(password); // Has special chars
  }

 Future<AuthResult> signInWithPersistence(
    String email,
    String password,
    bool rememberMe,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult(error: 'Failed to sign in');
      }

      if (!user.emailVerified) {
        return AuthResult(
          user: user,
          requiresVerification: true,
          error: 'Please verify your email before continuing',
        );
      }

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_persistentLoginKey, true);
        await prefs.setString(_userEmailKey, email);
        await _updateSessionTime();
      }

      _authStateController.add(user);
      return AuthResult(user: user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _getReadableErrorMessage(e.code));
    }
  }

  Future<AuthResult> register(String email, String password) async {
    if (!isPasswordStrong(password)) {
      return AuthResult(
        error:
            'Password must be at least 8 characters long and contain uppercase, '
            'lowercase, numbers, and special characters',
      );
    }

    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) {
        return AuthResult(error: 'Registration failed');
      }

      // Send email verification
      await user.sendEmailVerification();

      return AuthResult(
        user: user,
        requiresVerification: true,
        error: 'Please check your email to verify your account',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _getReadableErrorMessage(e.code));
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all stored preferences
      await _auth.signOut();
      _authStateController.add(null);
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    bool isDeviceSupported = await _localAuth.isDeviceSupported();

    if (!canCheckBiometrics || !isDeviceSupported) {
      // Fallback to password authentication
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_userEmailKey);
      return email != null && await isSessionValid();
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your account',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow fallback to device password/PIN
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        await _updateSessionTime();
      }
      return authenticated;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getReadableErrorMessage(e.code));
    }
  }

  Future<bool> verifyEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      return true;
    }
    return false;
  }

  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartStr = prefs.getString(_sessionTimeKey);

    if (sessionStartStr == null) return false;

    final sessionStart = DateTime.parse(sessionStartStr);
    final now = DateTime.now();

    if (now.difference(sessionStart) > _sessionTimeout) {
      await signOut();
      return false;
    }

    return true;
  }

  Future<void> _updateSessionTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTimeKey, DateTime.now().toIso8601String());
  }

  String _getReadableErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'weak-password':
        return 'Please enter a stronger password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid login credentials';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred. Please try again';
    }
  }

  void dispose() {
    _authStateController.close();
  }

  Future<String> getInitialRoute() async {
    try {
      // Check if user is already signed in
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        // No user signed in, check if there's a persistent login
        final prefs = await SharedPreferences.getInstance();
        final hasPersistentLogin = prefs.getBool(_persistentLoginKey) ?? false;

        if (hasPersistentLogin) {
          // Check if the session is still valid
          final isValid = await isSessionValid();
          if (isValid) {
            return '/home';
          }
        }
        return '/login';
      }

      // User is signed in, check if email is verified
      if (!currentUser.emailVerified) {
        return '/verify-email';
      }

      // Check if session is valid
      final isValid = await isSessionValid();
      if (!isValid) {
        await signOut();
        return '/login';
      }

      return '/home';
    } catch (e) {
      // If there's any error, default to login screen
      return '/login';
    }
  }

}
