import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:truthy_wifi_manager/screens/auth/login_screen.dart';
import 'package:truthy_wifi_manager/widgets/animated_background.dart';
import '../../widgets/glassmorphic_card.dart';

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
  String? _errorMessage;

  // For password strength indicator
  double _passwordStrength = 0;
  bool _isPasswordMatch = false;

  // Form steps
  final int _totalSteps = 3;
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
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

    // Add listeners for real-time validation
    _passwordController.addListener(_updatePasswordStrength);
    _confirmPasswordController.addListener(_checkPasswordMatch);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;

    // Check for length
    if (password.length >= 8) strength += 0.25;

    // Check for uppercase letters
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;

    // Check for lowercase letters
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.25;

    // Check for numbers and special characters
    if (RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(password))
      strength += 0.25;

    setState(() {
      _passwordStrength = strength;
    });

    _checkPasswordMatch();
  }

  void _checkPasswordMatch() {
    setState(() {
      _isPasswordMatch = _confirmPasswordController.text.isNotEmpty &&
          _passwordController.text == _confirmPasswordController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

                          // Main registration card
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
                                      label: 'Create your account',
                                      child: Text(
                                        'Create Your Account',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Join Truthy WiFi Manager to manage your subscriptions effortlessly',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Progress indicator
                                    _buildStepIndicator(theme),
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

                                    // Form steps
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child,
                                          Animation<double> animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.1, 0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _buildCurrentStep(theme),
                                    ),

                                    const SizedBox(height: 24),

                                    // Navigation buttons
                                    _buildNavigationButtons(theme),

                                    // Login link
                                    const SizedBox(height: 24),
                                    Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Already have an account? ',
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                          Semantics(
                                            button: true,
                                            label: 'Log in to existing account',
                                            hint:
                                                'Double tap to navigate to login screen',
                                            child: TextButton(
                                              onPressed: () => Navigator
                                                  .pushReplacementNamed(
                                                      context, '/login'),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                              ),
                                              child: Text(
                                                'Log In',
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

  Widget _buildStepIndicator(ThemeData theme) {
    return Row(
      children: List.generate(
        _totalSteps,
        (index) {
          final isActive = index + 1 <= _currentStep;
          final isCurrentStep = index + 1 == _currentStep;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isActive
                              ? theme.colorScheme.primary
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    Semantics(
                      label: 'Step ${index + 1} of $_totalSteps',
                      value: isCurrentStep
                          ? 'Current step'
                          : isActive
                              ? 'Completed'
                              : 'Not completed',
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? theme.colorScheme.primary
                              : Colors.white.withOpacity(0.3),
                          border: isCurrentStep
                              ? Border.all(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.5),
                                  width: 3,
                                )
                              : null,
                        ),
                        child: Center(
                          child: isActive
                              ? Icon(
                                  isCurrentStep ? Icons.edit : Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (index < _totalSteps - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isActive && index + 1 < _currentStep
                              ? theme.colorScheme.primary
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getStepName(index + 1),
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrentStep
                        ? theme.colorScheme.primary
                        : Colors.white.withOpacity(0.7),
                    fontWeight:
                        isCurrentStep ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStepName(int step) {
    switch (step) {
      case 1:
        return 'Account';
      case 2:
        return 'Contact';
      case 3:
        return 'Password';
      default:
        return 'Step $step';
    }
  }

  Widget _buildCurrentStep(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildAccountStep(theme);
      case 2:
        return _buildContactStep(theme);
      case 3:
        return _buildPasswordStep(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccountStep(ThemeData theme) {
    return Column(
      key: ValueKey('account-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step title
        Semantics(
          label: 'Account Information',
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

        // Email tips
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Why we need your email:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTipItem('Account recovery', theme),
              _buildTipItem('Important notifications', theme),
              _buildTipItem('Subscription details', theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactStep(ThemeData theme) {
    return Column(
      key: ValueKey('contact-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step title
        Semantics(
          label: 'Contact Information',
          child: Row(
            children: [
              Icon(
                Icons.contact_phone_outlined,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Phone field
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

        // Phone verification info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Why we need your phone:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTipItem('Account verification', theme),
              _buildTipItem('Secure login with OTP', theme),
              _buildTipItem('Service updates', theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(ThemeData theme) {
    return Column(
      key: ValueKey('password-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step title
        Semantics(
          label: 'Set Password',
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Set Your Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Password field
        _buildLabeledTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a strong password',
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
            if (!ref.read(authServiceProvider).isPasswordStrong(value)) {
              return 'Password not strong enough';
            }
            return null;
          },
          theme: theme,
        ),
        const SizedBox(height: 8),

        // Password strength indicator
        _buildPasswordStrengthIndicator(theme),
        const SizedBox(height: 16),

        // Confirm Password field
        _buildLabeledTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Confirm your password',
          obscureText: _obscureConfirmPassword,
          prefixIcon: Icons.lock_outline,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_confirmPasswordController.text.isNotEmpty)
                Icon(
                  _isPasswordMatch ? Icons.check_circle : Icons.cancel,
                  size: 20,
                  color: _isPasswordMatch ? Colors.green : Colors.red[300],
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ],
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
          theme: theme,
        ),
        const SizedBox(height: 16),

        // Password requirements
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password must contain:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordRequirement(
                'At least 8 characters',
                RegExp(r'.{8,}').hasMatch(_passwordController.text),
                theme,
              ),
              _buildPasswordRequirement(
                'At least one uppercase letter (A-Z)',
                RegExp(r'[A-Z]').hasMatch(_passwordController.text),
                theme,
              ),
              _buildPasswordRequirement(
                'At least one lowercase letter (a-z)',
                RegExp(r'[a-z]').hasMatch(_passwordController.text),
                theme,
              ),
              _buildPasswordRequirement(
                'At least one number or special character',
                RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]')
                    .hasMatch(_passwordController.text),
                theme,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(ThemeData theme) {
    Color getStrengthColor() {
      if (_passwordStrength < 0.25) return Colors.red;
      if (_passwordStrength < 0.5) return Colors.orange;
      if (_passwordStrength < 0.75) return Colors.yellow;
      return Colors.green;
    }

    String getStrengthText() {
      if (_passwordStrength < 0.25) return 'Weak';
      if (_passwordStrength < 0.5) return 'Fair';
      if (_passwordStrength < 0.75) return 'Good';
      return 'Strong';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            Text(
              getStrengthText(),
              style: TextStyle(
                fontSize: 12,
                color: getStrengthColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: getStrengthColor(),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirement(String text, bool isMet, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? Colors.green : Colors.white30,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.white70 : Colors.white30,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        if (_currentStep > 1)
          TextButton.icon(
            onPressed: _previousStep,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          )
        else
          const SizedBox(width: 100),

        // Next/Register button
        Semantics(
          button: true,
          enabled: !_isLoading,
          label: _currentStep < _totalSteps ? 'Next step' : 'Create account',
          hint:
              'Double tap to ${_currentStep < _totalSteps ? 'proceed to next step' : 'create your account'}',
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _nextStepOrRegister,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_currentStep < _totalSteps
                    ? Icons.arrow_forward
                    : Icons.check_circle),
            label: Text(_currentStep < _totalSteps ? 'Next' : 'Register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        if (_emailController.text.isEmpty ||
            !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text)) {
          setState(() {
            _errorMessage = 'Please enter a valid email address';
          });
          return false;
        }
        return true;

      case 2:
        if (_phoneNumber == null || _isoCodeEnum == null) {
          setState(() {
            _errorMessage = 'Please enter a valid phone number';
          });
          return false;
        }

        final parsedPhoneNumber = PhoneNumber.parse(
          _phoneNumber!,
          callerCountry: _isoCodeEnum!,
        );

        if (!parsedPhoneNumber.isValid()) {
          setState(() {
            _errorMessage =
                'Please enter a valid phone number for the selected country';
          });
          return false;
        }
        return true;

      case 3:
        if (_passwordController.text.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter a password';
          });
          return false;
        }

        if (!ref
            .read(authServiceProvider)
            .isPasswordStrong(_passwordController.text)) {
          setState(() {
            _errorMessage = 'Password does not meet the requirements';
          });
          return false;
        }

        if (_confirmPasswordController.text != _passwordController.text) {
          setState(() {
            _errorMessage = 'Passwords do not match';
          });
          return false;
        }
        return true;

      default:
        return false;
    }
  }

  void _nextStepOrRegister() {
    if (!_validateCurrentStep()) return;

    setState(() {
      _errorMessage = null;
    });

    if (_currentStep < _totalSteps) {
      setState(() {
        _currentStep++;
      });
    } else {
      _register();
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = ref.read(authServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      try {
        // Step 1: Register with email/password
        final emailResult = await authService.register(email, password);
        if (emailResult.error != null) {
          setState(() {
            _errorMessage = emailResult.error!;
            _isLoading = false;
          });
          return;
        }

        if (emailResult.requiresVerification) {
          _showSnackBar('Verification email sent. Please check your inbox.');
        }

        // Step 2: Proceed with phone verification
        if (_phoneNumber != null && _isoCodeEnum != null) {
          await authService.registerWithPhoneNumber(
            phoneNumber: _phoneNumber!,
            onCodeSent: (verificationId, resendToken) {
              _showVerificationDialog(verificationId);
            },
            onCompleted: (result) {
              if (result.user != null) {
                _showRegistrationSuccess();
              }
            },
            onError: (error) {
              setState(() {
                _errorMessage = error;
                _isLoading = false;
              });
            },
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showVerificationDialog(String verificationId) {
    final codeController = TextEditingController();

    setState(() {
      _isLoading = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sms_outlined,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'We\'ve sent a verification code to $_phoneNumber',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Enter 6-digit code',
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
                _showRegistrationSuccess();
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

  void _showRegistrationSuccess() {
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your account has been created successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your email to verify your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text('Continue to Dashboard'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
}
