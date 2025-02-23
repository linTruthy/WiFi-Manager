import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

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
  final LocalAuthentication localAuth = LocalAuthentication();
  static const String _persistentLoginKey = 'persistentLogin';
  static const String _userEmailKey = 'userEmail';
  static const String _userPhoneKey = 'userPhone';
  static const String _sessionTimeKey = 'sessionStartTime';
  static const Duration _sessionTimeout =
      Duration(days: 7); // Extended to a week
  final _authStateController = StreamController<User?>.broadcast();

  Stream<User?> get authStateChanges => _authStateController.stream;
  User? get currentUser => _auth.currentUser;

  // Check if password meets strength requirements
  bool isPasswordStrong(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  // Sign in with email and password with persistence option
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
        await storage.write(key: 'userEmail', value: email);
        await storage.write(key: 'userPassword', value: password);
        await _updateSessionTime();
      }
      _authStateController.add(user);
      return AuthResult(user: user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _getReadableErrorMessage(e.code));
    }
  }

  // Sign in with phone number
  Future<void> signInWithPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(AuthResult) onCompleted,
    Function(String)? onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_persistentLoginKey, true);
            await prefs.setString(_userPhoneKey, phoneNumber);
            await _updateSessionTime();
            _authStateController.add(user);
            onCompleted(AuthResult(user: user));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError?.call(_getReadableErrorMessage(e.code));
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError?.call('An unexpected error occurred: $e');
    }
  }

  // Verify phone code
  Future<AuthResult> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return AuthResult(error: 'Failed to sign in');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_persistentLoginKey, true);
      await prefs.setString(_userPhoneKey, user.phoneNumber ?? '');
      await _updateSessionTime();
      _authStateController.add(user);
      return AuthResult(user: user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _getReadableErrorMessage(e.code));
    }
  }

  // Register with email
  Future<AuthResult> register(String email, String password) async {
    if (!isPasswordStrong(password)) {
      return AuthResult(
        error:
            'Password must be at least 8 characters long and contain uppercase, lowercase, numbers, and special characters',
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
      await user.sendEmailVerification();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_persistentLoginKey, true);
      await prefs.setString(_userEmailKey, email);
      await prefs.setString('userPassword', password); // Temporary for demo
      await _updateSessionTime();
      return AuthResult(
        user: user,
        requiresVerification: true,
        error: 'Please check your email to verify your account',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _getReadableErrorMessage(e.code));
    }
  }

  // Sign out and clear persistence
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistentLoginKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_sessionTimeKey);
      await prefs.remove('userPassword');
      await storage.deleteAll();
      await _auth.signOut();
      _authStateController.add(null);
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Biometric authentication
  Future<bool> authenticateWithBiometrics() async {
    bool canCheckBiometrics = await localAuth.canCheckBiometrics;
    bool isDeviceSupported = await localAuth.isDeviceSupported();
    if (!canCheckBiometrics || !isDeviceSupported) {
      return false; // Fallback to manual login if biometrics unavailable
    }
    try {
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access your account',
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        await _updateSessionTime();
        final prefs = await SharedPreferences.getInstance();
        final email = await storage.read(key: 'userEmail');
        final password = await storage.read(key: 'userPassword'); // Temporary
        final phone = prefs.getString(_userPhoneKey);
        if (email != null && password != null) {
          await signInWithPersistence(email, password, true);
        } else if (phone != null) {
          // For phone, we can't auto-login without code, so assume session valid
          _authStateController.add(_auth.currentUser);
        }
      }
      return authenticated;
    } catch (e) {
      return false;
    }
  }

  // Check if session is valid
  Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartStr = prefs.getString(_sessionTimeKey);
    final persistentLogin = prefs.getBool(_persistentLoginKey) ?? false;
    if (!persistentLogin || sessionStartStr == null) return false;
    final sessionStart = DateTime.parse(sessionStartStr);
    final now = DateTime.now();
    if (now.difference(sessionStart) > _sessionTimeout) {
      await signOut();
      return false;
    }
    return _auth.currentUser != null;
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
      case 'invalid-verification-code':
        return 'The SMS code entered is invalid';
      case 'invalid-phone-number':
        return 'The phone number format is invalid';
      case 'missing-verification-code':
        return 'Please enter the SMS code';
      default:
        return 'An error occurred. Please try again';
    }
  }

  Future<String> getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final persistentLogin = prefs.getBool(_persistentLoginKey) ?? false;
    if (!persistentLogin) return '/login';
    final isValid = await isSessionValid();
    if (!isValid) return '/login';
    final email = prefs.getString(_userEmailKey);
    final password = prefs.getString('userPassword');
    final phone = prefs.getString(_userPhoneKey);
    if (email != null && password != null) {
      final result = await signInWithPersistence(email, password, true);
      if (result.user != null && !result.requiresVerification) {
        return '/home';
      }
    } else if (phone != null && _auth.currentUser != null) {
      return '/home';
    }
    return '/login';
  }

  void dispose() {
    _authStateController.close();
  }

  Future<bool> verifyEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      return true;
    }
    return false;
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getReadableErrorMessage(e.code));
    }
  }

  Future<void> registerWithPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(AuthResult) onCompleted,
    Function(String)? onError,
  }) async {
    await signInWithPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onCompleted: onCompleted,
      onError: onError,
    );
  }
}
