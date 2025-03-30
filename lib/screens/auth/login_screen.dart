import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:truthy_wifi_manager/widgets/animated_background.dart';
import 'package:truthy_wifi_manager/widgets/glassmorphic_card.dart';
import '../../services/auth_service.dart';

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

  final _formKey = GlobalKey<FormState>();
  String? _phoneNumber;
  String? _isoCode;
  IsoCode? _isoCodeEnum;

  bool _rememberMe = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _errorMessage;
  String _selectedLoginMethod = 'email';
  bool _canUseBiometrics = false;

  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  AppUpdateInfo? _updateInfo;
  bool _flexibleUpdateAvailable = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _checkForUpdate();
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _checkSessionAndBiometrics();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          const AnimatedBackground(),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 450),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo or app icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.wifi,
                              size: 60,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Main login card
                          GlassmorphicCard(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Semantics(
                                      header: true,
                                      label: 'Login to Truthy WiFi Manager',
                                      child: Text(
                                        'Welcome Back!',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Log in to manage your WiFi subscriptions',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Method selector
                                    Semantics(
                                      label: 'Login method selector',
                                      hint:
                                          'Choose between email or phone login',
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
                                              _errorMessage = null;
                                            });
                                          },
                                          style: ButtonStyle(
                                            backgroundColor: WidgetStateProperty
                                                .resolveWith<Color>(
                                              (Set<WidgetState> states) {
                                                if (states.contains(
                                                    WidgetState.selected)) {
                                                  return theme
                                                      .colorScheme.primary
                                                      .withOpacity(0.7);
                                                }
                                                return Colors.white
                                                    .withOpacity(0.1);
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Error message display
                                    if (_errorMessage != null)
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(12),
                                        margin:
                                            const EdgeInsets.only(bottom: 20),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.red[300],
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: TextStyle(
                                                  color: Colors.red[300],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  size: 16),
                                              color: Colors.red[300],
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () => setState(
                                                  () => _errorMessage = null),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Email/Phone form fields
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: _selectedLoginMethod == 'email'
                                          ? _buildEmailLoginForm(theme)
                                          : _buildPhoneLoginForm(theme),
                                    ),

                                    // Countdown message for rate limiting
                                    if (_remainingSeconds > 0)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 16.0),
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.amber.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.amber
                                                    .withOpacity(0.5),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.timer,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Please wait $_remainingSeconds seconds',
                                                  style: TextStyle(
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 24),

                                    // Login button
                                    Semantics(
                                      button: true,
                                      enabled:
                                          !_isLoading && _remainingSeconds == 0,
                                      label: _selectedLoginMethod == 'email'
                                          ? 'Log in'
                                          : 'Send OTP',
                                      hint:
                                          'Double tap to ${_selectedLoginMethod == 'email' ? 'log in' : 'send OTP code'}',
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: (_isLoading ||
                                                  _remainingSeconds > 0)
                                              ? null
                                              : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                            shadowColor: theme
                                                .colorScheme.primary
                                                .withOpacity(0.4),
                                          ),
                                          child: _isLoading
                                              ? SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      _selectedLoginMethod ==
                                                              'email'
                                                          ? 'Log In'
                                                          : 'Send OTP',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      _selectedLoginMethod ==
                                                              'email'
                                                          ? Icons.login
                                                          : Icons.send,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),

                                    // Biometric login option
                                    if (_canUseBiometrics) ...[
                                      const SizedBox(height: 20),
                                      Semantics(
                                        button: true,
                                        enabled: !_isLoading &&
                                            _remainingSeconds == 0,
                                        label: 'Log in with biometrics',
                                        hint:
                                            'Double tap to authenticate using fingerprint or face ID',
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: (_isLoading ||
                                                    _remainingSeconds > 0)
                                                ? null
                                                : _loginWithBiometrics,
                                            icon: const Icon(Icons.fingerprint),
                                            label: const Text('Use Biometrics'),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                              side: BorderSide(
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.7),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // Register link
                                    const SizedBox(height: 24),
                                    Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Don\'t have an account? ',
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                          Semantics(
                                            button: true,
                                            label: 'Create new account',
                                            hint:
                                                'Double tap to navigate to registration screen',
                                            child: TextButton(
                                              onPressed: () => Navigator
                                                  .pushReplacementNamed(
                                                      context, '/register'),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                              ),
                                              child: Text(
                                                'Sign Up',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Version info
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Truthy WiFi Manager v3.1.0',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmailLoginForm(ThemeData theme) {
    return Column(
      key: ValueKey('email-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email field
        _buildLabeledTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Enter a valid email address';
            }
            return null;
          },
          theme: theme,
        ),
        const SizedBox(height: 20),

        // Password field
        _buildLabeledTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            return null;
          },
          theme: theme,
        ),
        const SizedBox(height: 16),

        // Remember me & Forgot password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Remember me
            Semantics(
              label: 'Remember me checkbox',
              hint: 'Toggle to stay logged in on this device',
              child: Row(
                children: [
                  Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      checkColor: Colors.black,
                      fillColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return theme.colorScheme.primary;
                          }
                          return Colors.white.withOpacity(0.2);
                        },
                      ),
                    ),
                  ),
                  const Text(
                    'Remember me',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            // Forgot password
            Semantics(
              button: true,
              label: 'Forgot Password',
              hint: 'Double tap to reset your password',
              child: TextButton(
                onPressed: _resetPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: theme.colorScheme.primary.withOpacity(0.9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneLoginForm(ThemeData theme) {
    return Column(
      key: ValueKey('phone-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Phone number input field',
          hint: 'Enter your phone number with country code',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phone Number',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntlPhoneField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      hintText: 'Enter your phone number',
                      hintStyle: TextStyle(color: Colors.white60),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                    initialCountryCode: 'UG',
                    disableLengthCheck: true,
                    dropdownIcon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white70,
                    ),
                    dropdownTextStyle: TextStyle(color: Colors.white),
                    dropdownIconPosition: IconPosition.trailing,
                    flagsButtonPadding: EdgeInsets.symmetric(horizontal: 8),
                    showDropdownIcon: true,
                    onChanged: (phone) {
                      setState(() {
                        _phoneNumber = phone.completeNumber;
                        _isoCode = phone.countryISOCode;
                        _isoCodeEnum = IsoCode.values.firstWhere(
                          (code) => code.name == _isoCode,
                          orElse: () => IsoCode.UG,
                        );
                      });
                    },
                    invalidNumberMessage: 'Invalid phone number',
                    validator: (phone) {
                      if (_phoneNumber == null || _phoneNumber!.isEmpty) {
                        return 'Phone number is required';
                      }
                      return null;
                    },
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Additional instructions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'We\'ll send you a verification code via SMS',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ThemeData theme,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return Semantics(
      textField: true,
      label: label,
      hint: hint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onTap: onTap,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white60),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: Colors.white70, size: 20)
                  : null,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red[300]!,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red[300]!,
                  width: 1.5,
                ),
              ),
              errorStyle: TextStyle(color: Colors.red[300]),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
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
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    try {
      final success = await authService.authenticateWithBiometrics();
      if (success) {
        final isValid = await authService.isSessionValid();
        if (isValid) {
          _navigateToHome();
        } else {
          _showSnackBar('Biometric login failed. Please use email or phone.');
        }
      } else {
        setState(() => _errorMessage = 'Biometric authentication failed.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Authentication error: $e');
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
        _errorMessage = null;
      });

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
        setState(() => _errorMessage = 'Login error: $e');
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    try {
      final success = await authService.resetPassword(email);
      if (success) {
        _showSnackBar(
            'Password reset email sent to $email. Please check your inbox.',
            isError: false);
      }
    } catch (e) {
      _handleAuthError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleAuthError(String error) {
    if (error.contains('too-many-requests')) {
      setState(() {
        _remainingSeconds = 30;
      });
      _startCountdown();
      _showSnackBar(
          'Too many attempts. Please wait $_remainingSeconds seconds.');
    } else {
      setState(() => _errorMessage = error);
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 48,
              color: Colors.amber,
            ),
            SizedBox(height: 16),
            Text(
              'Please verify your email address to log in. Check your inbox for a verification link.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final authService = ref.read(authServiceProvider);
              await authService.verifyEmail();
              Navigator.pop(context);
              _showSnackBar('Verification email resent.', isError: false);
            },
            child: const Text('Resend'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
  }

  void _showVerificationDialog(String verificationId) {
    final codeController = TextEditingController();
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sms_outlined,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'ve sent a verification code to your phone. Please enter it below.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'SMS Code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: '• • • • • •',
                counterText: '',
              ),
              style: const TextStyle(
                letterSpacing: 8,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              final authService = ref.read(authServiceProvider);
              final result = await authService.verifyPhoneCode(
                verificationId: verificationId,
                smsCode: codeController.text.trim(),
              );

              setState(() => _isLoading = false);

              if (result.user != null) {
                Navigator.pop(context);
                _navigateToHome();
              } else {
                _showSnackBar(result.error ?? 'Verification failed');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Verify'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    setState(() {
      if (isError) {
        _errorMessage = message;
      } else {
        _errorMessage = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
          textColor: Colors.white,
        ),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }
}
