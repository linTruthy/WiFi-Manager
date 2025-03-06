import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  bool _rememberMe = true; // Default to true for persistence
  bool _isLoading = false;
  String? _errorMessage;

  bool _canUseBiometrics = false;
  String _selectedLoginMethod =
      'email'; // 'email' or 'phone' for SegmentedButton
  int _remainingSeconds = 0; // For rate limiting countdown
  Timer? _countdownTimer;
  final _formKey = GlobalKey<FormState>();
  String? _phoneNumber;
  String? _isoCode;
  IsoCode? _isoCodeEnum;

  bool _obscurePassword = true;
  AppUpdateInfo? _updateInfo;
  bool _flexibleUpdateAvailable = false;
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _checkForUpdate(); // Check for updates when the screen loads
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    _checkSessionAndBiometrics();
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      setState(() {
        _updateInfo = info;
      });
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        _showUpdateDialog();
      }
    } catch (e) {
      _showSnackBar('Error checking for update: $e');
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of Truthy WiFi Manager is available. Update now to get the latest features and improvements.',
        ),
        actions: [
          if (_updateInfo?.flexibleUpdateAllowed == true)
            TextButton(
              onPressed: () {
                _startFlexibleUpdate();
                Navigator.pop(context);
              },
              child: const Text('Flexible Update'),
            ),
          if (_updateInfo?.immediateUpdateAllowed == true)
            ElevatedButton(
              onPressed: () {
                _performImmediateUpdate();
                Navigator.pop(context);
              },
              child: const Text('Update Now'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        ],
      ),
    );
  }
Future<void> _performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.inAppUpdateFailed) {
        _showSnackBar('Immediate update failed. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Error during immediate update: $e');
    }
  }

  Future<void> _startFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      setState(() {
        _flexibleUpdateAvailable = true;
      });
      _showSnackBar('Flexible update started. Complete it when ready.');
    } catch (e) {
      _showSnackBar('Error starting flexible update: $e');
    }
  }

  Future<void> _completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
      _showSnackBar('Update completed successfully!');
      setState(() {
        _flexibleUpdateAvailable = false;
      });
    } catch (e) {
      _showSnackBar('Error completing flexible update: $e');
    }
  }

  Future<void> _checkSessionAndBiometrics() async {
    final authService = ref.read(authServiceProvider);
    final canCheckBiometrics = await authService.localAuth.canCheckBiometrics;
    final isDeviceSupported = await authService.localAuth.isDeviceSupported();
    setState(() => _canUseBiometrics = canCheckBiometrics && isDeviceSupported);

    if (await authService.isSessionValid()) {
      if (_canUseBiometrics) {
        _promptBiometricAuth();
      } else {
        _navigateToHome();
      }
    }
  }

  Future<void> _promptBiometricAuth() async {
    final authService = ref.read(authServiceProvider);
    final authenticated = await authService.authenticateWithBiometrics();
    if (authenticated) {
      _navigateToHome();
    } else {
      setState(() => _errorMessage =
          'Biometric authentication failed. Please sign in manually.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          _AnimatedBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlassmorphicCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    label: 'Login header',
                                    child: const Text(
                                      'Welcome Back!',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Log in to manage your WiFi subscriptions.',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  // Toggle between Email and Phone Login
                                  // Segmented Button for Login Method
                                  Semantics(
                                    label: 'Login method selector',
                                    child: Center(
                                      child: SegmentedButton<String>(
                                        segments: const [
                                          ButtonSegment<String>(
                                            value: 'email',
                                            label: Text('Email'),
                                            icon: Icon(Icons.email),
                                          ),
                                          ButtonSegment<String>(
                                            value: 'phone',
                                            label: Text('Phone'),
                                            icon: Icon(Icons.phone),
                                          ),
                                        ],
                                        selected: {_selectedLoginMethod},
                                        onSelectionChanged: (newSelection) {
                                          setState(() {
                                            _selectedLoginMethod =
                                                newSelection.first;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_errorMessage != null)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 14),
                                      ),
                                    ),
                                  // Email or Phone Field
                                  if (_selectedLoginMethod == 'email') ...[
                                    Semantics(
                                      label: 'Email input field',
                                      child: TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          hintText: 'Enter your email',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          prefixIcon: const Icon(Icons.email),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Email is required';
                                          }
                                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                              .hasMatch(value)) {
                                            return 'Enter a valid email address';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.next,
                                      ),
                                    ),
                                  ] else ...[
                                    Semantics(
                                      label: 'Phone number input field',
                                      child: IntlPhoneField(
                                        controller: _phoneController,
                                        decoration: InputDecoration(
                                          labelText: 'Phone Number',
                                          hintText: 'Enter your phone number',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        initialCountryCode: 'UG',
                                        onChanged: (phone) {
                                          setState(() {
                                            _phoneNumber = phone.completeNumber;
                                            _isoCode = phone.countryISOCode;
                                            _isoCodeEnum =
                                                IsoCode.values.firstWhere(
                                              (code) => code.name == _isoCode,
                                              orElse: () => IsoCode.UG,
                                            );
                                          });
                                        },
                                        validator: (phone) {
                                          if (_phoneNumber == null ||
                                              _phoneNumber!.isEmpty) {
                                            return 'Phone number is required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Password Field (only for email login)
                                  if (_selectedLoginMethod == 'email')
                                    Semantics(
                                      label: 'Password input field',
                                      child: TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          hintText: 'Enter your password',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          prefixIcon: const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Password is required';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _login(),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  // Remember Me Checkbox (only for email login)
                                  if (_selectedLoginMethod == 'email')
                                    Semantics(
                                      label: 'Remember me checkbox',
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                          ),
                                          const Text('Remember me'),
                                        ],
                                      ),
                                    ),
                                  // Forgot Password Link (only for email login)
                                  if (_selectedLoginMethod == 'email')
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Semantics(
                                        label: 'Forgot password link',
                                        child: TextButton(
                                          onPressed: _resetPassword,
                                          child: const Text('Forgot Password?'),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  // Rate Limiting Feedback
                                  if (_remainingSeconds > 0)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        'Too many attempts. Please wait $_remainingSeconds seconds.',
                                        style: const TextStyle(
                                            color: Colors.redAccent),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  const SizedBox(height: 8),

                                  // Login Button
                                  Semantics(
                                    label: 'Login button',
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: (_isLoading ||
                                                _remainingSeconds > 0)
                                            ? null
                                            : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                              )
                                            : Text(
                                                _selectedLoginMethod != 'email'
                                                    ? 'Send OTP'
                                                    : 'Log In',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                      ),
                                    ),
                                  ),

                                  // Biometric Login Option
                                  if (_canUseBiometrics) ...[
                                    const SizedBox(height: 16),
                                    Semantics(
                                      label: 'Biometric login button',
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: (_isLoading ||
                                                  _remainingSeconds > 0)
                                              ? null
                                              : _loginWithBiometrics,
                                          icon: const Icon(Icons.fingerprint),
                                          label: const Text(
                                              'Log In with Biometrics'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Sign Up Link
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Don’t have an account? ',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      Semantics(
                                        label: 'Sign up link',
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pushReplacementNamed(
                                                  context, '/register'),
                                          child: const Text('Sign Up'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isLoading = true;
    });

    final authService = ref.read(authServiceProvider);
    try {
      final success = await authService.authenticateWithBiometrics();
      if (success) {
        final isValid = await authService.isSessionValid();
        if (isValid) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showSnackBar('Biometric login failed. Please use email or phone.');
        }
      } else {
        _showSnackBar('Biometric authentication failed.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      _errorMessage = '';
      final authService = ref.read(authServiceProvider);

      try {
        if (_selectedLoginMethod == 'phone') {
          if (_phoneNumber == null || _isoCodeEnum == null) {
            _showSnackBar('Please enter a valid phone number');
            setState(() => _isLoading = false);
            return;
          }
          final parsedPhoneNumber =
              PhoneNumber.parse(_phoneNumber!, callerCountry: _isoCodeEnum!);
          if (!parsedPhoneNumber.isValid()) {
            _showSnackBar('Invalid phone number format');
            setState(() => _isLoading = false);
            return;
          }

          await authService.signInWithPhoneNumber(
            phoneNumber: _phoneNumber!,
            onCodeSent: (verificationId, resendToken) {
              _showVerificationDialog(verificationId);
            },
            onCompleted: (result) {
              if (result.user != null) {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            onError: (error) => _handleAuthError(error),
          );
        } else {
          final email = _emailController.text.trim();
          final password = _passwordController.text;
          final result = await authService.signInWithPersistence(
              email, password, _rememberMe);
          if (result.error != null) {
            _handleAuthError(result.error!);
            if (result.requiresVerification) {
              _promptEmailVerification();
            }
          } else if (result.user != null) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } catch (e) {
        _showSnackBar('An error occurred: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showSnackBar('Please enter a valid email to reset your password.');
      return;
    }

    final authService = ref.read(authServiceProvider);
    try {
      final success = await authService.resetPassword(email);
      if (success) {
        _showSnackBar('Password reset email sent. Check your inbox.');
      }
    } catch (e) {
      _handleAuthError(e.toString());
    }
  }

  void _handleAuthError(String error) {
    if (error.contains('too-many-requests')) {
      setState(() {
        _remainingSeconds = 30; // Example: 30-second cooldown
      });
      _startCountdown();
      _showSnackBar(
          'Too many attempts. Please wait $_remainingSeconds seconds.');
    } else {
      _showSnackBar(error);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _promptEmailVerification() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: const Text(
          'Please verify your email address to log in. Check your inbox for a verification link.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.verifyEmail();
              Navigator.pop(context);
              _showSnackBar('Verification email resent.');
            },
            child: const Text('Resend'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(String verificationId) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'SMS Code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              final result = await authService.verifyPhoneCode(
                verificationId: verificationId,
                smsCode: codeController.text.trim(),
              );
              if (result.user != null) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home');
              } else {
                _showSnackBar(result.error ?? 'Verification failed');
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /* void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: const Text(
            'Please check your email and verify your account before continuing.'),
        actions: [
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.verifyEmail();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification email sent')));
            },
            child: const Text('Resend Email'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } */

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

class _AnimatedBackground extends StatefulWidget {
  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GradientPainter(animation: _controller),
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final Animation<double> animation;
  _GradientPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment(
        0.7 * sin(animation.value * pi * 2),
        0.7 * cos(animation.value * pi * 2),
      ),
      colors: const [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF1A1A1A)],
      stops: const [0.0, 0.5, 1.0],
      radius: 1.5,
    );
    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) => true;
}

class _GlassmorphicCard extends StatelessWidget {
  final Widget child;
  const _GlassmorphicCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _smsCodeController = TextEditingController();
  String? _phoneNumber;
  String? _isoCode;
  IsoCode? _isoCodeEnum;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          _AnimatedBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlassmorphicCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Semantics(
                                    label: 'Sign up header',
                                    child: const Text(
                                      'Create Your Account',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Join Truthy WiFi Manager to manage your subscriptions effortlessly.',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  //  if (!_usePhone) ...[
                                  Semantics(
                                    label: 'Email input field',
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'Enter your email',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        prefixIcon: const Icon(Icons.email),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Email is required';
                                        }
                                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                            .hasMatch(value)) {
                                          return 'Enter a valid email address';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Semantics(
                                    label: 'Phone number input field',
                                    child: IntlPhoneField(
                                      decoration: InputDecoration(
                                        labelText: 'Phone Number',
                                        hintText: 'Enter your phone number',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      initialCountryCode: 'UG',
                                      onChanged: (phone) {
                                        setState(() {
                                          _phoneNumber = phone.completeNumber;
                                          _isoCode = phone.countryISOCode;
                                          _isoCodeEnum =
                                              IsoCode.values.firstWhere(
                                            (code) => code.name == _isoCode,
                                            orElse: () => IsoCode.UG,
                                          );
                                        });
                                      },
                                      validator: (phone) {
                                        if (_phoneNumber == null ||
                                            _phoneNumber!.isEmpty) {
                                          return 'Phone number is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Semantics(
                                    label: 'Password input field',
                                    child: TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: 'Enter your password',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        prefixIcon: const Icon(Icons.lock),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password is required';
                                        }
                                        if (!ref
                                            .read(authServiceProvider)
                                            .isPasswordStrong(value)) {
                                          return 'Password must be at least 8 characters with uppercase, lowercase, numbers, and special characters';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.next,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Confirm Password Field
                                  Semantics(
                                    label: 'Confirm password input field',
                                    child: TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm Password',
                                        hintText: 'Re-enter your password',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        prefixIcon: const Icon(Icons.lock),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please confirm your password';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _register(),
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                  // Sign Up Button
                                  Semantics(
                                    label: 'Sign up button',
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _register,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                              )
                                            : const Text(
                                                'Sign Up',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Already have an account? ',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      Semantics(
                                        label: 'Login link',
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pushReplacementNamed(
                                                  context, '/login'),
                                          child: const Text('Log In'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final authService = ref.read(authServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final parsedPhoneNumber = _phoneNumber != null && _isoCodeEnum != null
          ? PhoneNumber.parse(_phoneNumber!, callerCountry: _isoCodeEnum!)
          : null;

      if (parsedPhoneNumber == null || !parsedPhoneNumber.isValid()) {
        _showSnackBar('Please enter a valid phone number');
        setState(() => _isLoading = false);
        return;
      }

      try {
        // Register with email and password
        final emailResult = await authService.register(email, password);
        if (emailResult.error != null) {
          _showSnackBar(emailResult.error!);
          setState(() => _isLoading = false);
          return;
        }

        if (emailResult.requiresVerification) {
          _showSnackBar('Verification email sent. Please check your inbox.');
        }

        // Optionally register with phone number
        await authService.registerWithPhoneNumber(
          phoneNumber: _phoneNumber!,
          onCodeSent: (verificationId, resendToken) {
            _showVerificationDialog(verificationId);
          },
          onCompleted: (result) {
            if (result.user != null) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
          onError: (error) => _showSnackBar(error),
        );
      } catch (e) {
        _showSnackBar('An error occurred: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showVerificationDialog(String verificationId) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'SMS Code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              final result = await authService.verifyPhoneCode(
                verificationId: verificationId,
                smsCode: codeController.text.trim(),
              );
              if (result.user != null) {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home');
              } else {
                _showSnackBar(result.error ?? 'Verification failed');
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}
