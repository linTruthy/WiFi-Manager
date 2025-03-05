// import 'dart:math';

// import 'package:isar/isar.dart';
// import 'plan.dart';

// part 'customer.g.dart';

// @Collection(inheritance: false)
// class Customer {
//   Id id = Isar.autoIncrement;

//   @Index(type: IndexType.value)
//   String name;

//   String contact;
//    @Index(type: IndexType.value)
//   bool isActive;

//   @Index(type: IndexType.value)
//   String wifiName;
//   String currentPassword;

//   DateTime subscriptionStart;
//   DateTime subscriptionEnd;

//   @Index(type: IndexType.value)
//   DateTime lastModified;

//   @Enumerated(EnumType.name)
//   PlanType planType;

//   // New fields for referral program
//   String? referredBy; // ID of the customer who referred this customer
//   DateTime?
//   referralRewardApplied; // Timestamp when the referral reward was applied
//   @Index(type: IndexType.value) // Add index for efficient lookup
//   String referralCode; // Unique referral code for this customer

//   Customer({
//     required this.name,
//     required this.contact,
//     required this.isActive,
//     required this.wifiName,
//     required this.currentPassword,
//     required this.subscriptionStart,
//     required this.subscriptionEnd,
//     required this.planType,
//     this.referredBy,
//     this.referralRewardApplied,
//   }) : referralCode =
//            _generateReferralCode(), // Generate referral code on creation
//        lastModified = DateTime.now();

//   // Convert Customer instance to JSON
//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'name': name,
//       'contact': contact,
//       'isActive': isActive,
//       'wifiName': wifiName,
//       'currentPassword': currentPassword,
//       'subscriptionStart': subscriptionStart.toIso8601String(),
//       'subscriptionEnd': subscriptionEnd.toIso8601String(),
//       'lastModified': lastModified.toIso8601String(),
//       'planType': planType.name,
//     };
//   }

//   // Create Customer instance from JSON
//   static Customer fromJson(Map<String, dynamic> json) {
//     return Customer(
//         name: json['name'] as String,
//         contact: json['contact'] as String,
//         isActive: json['isActive'] as bool,
//         wifiName: json['wifiName'] as String,
//         currentPassword: json['currentPassword'] as String,
//         subscriptionStart: DateTime.parse(json['subscriptionStart'] as String),
//         subscriptionEnd: DateTime.parse(json['subscriptionEnd'] as String),
//         planType: PlanType.values.firstWhere(
//           (e) => e.name == json['planType'],
//           orElse: () => PlanType.daily,
//         ),
//       )
//       ..id = json['id'] as int
//       ..lastModified = DateTime.parse(json['lastModified'] as String);
//   }
import 'dart:math';

import 'plan.dart';

//enum PlanType { daily, weekly, monthly }

class Customer {
  String id; // Changed from Id to String
  String name;
  String contact;
  bool isActive;
  String wifiName;
  String currentPassword;
  DateTime subscriptionStart;
  DateTime subscriptionEnd;
  DateTime lastModified;
  PlanType planType;
  String? referredBy;
  DateTime? referralRewardApplied;
  String referralCode;

  Customer({
    required this.name,
    required this.contact,
    required this.isActive,
    required this.wifiName,
    required this.currentPassword,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    required this.planType,
    this.referredBy,
    this.referralRewardApplied,
  })  : id = '', // Initialize as empty; will be set when saving
        referralCode = _generateReferralCode(),
        lastModified = DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact': contact,
      'isActive': isActive,
      'wifiName': wifiName,
      'currentPassword': currentPassword,
      'subscriptionStart': subscriptionStart.toIso8601String(),
      'subscriptionEnd': subscriptionEnd.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'planType': planType.name,
      'referredBy': referredBy,
      'referralRewardApplied': referralRewardApplied?.toIso8601String(),
      'referralCode': referralCode,
    };
  }

  static Customer fromJson(String id, Map<String, dynamic> json) {
    return Customer(
      name: json['name'] as String,
      contact: json['contact'] as String,
      isActive: json['isActive'] as bool,
      wifiName: json['wifiName'] as String,
      currentPassword: json['currentPassword'] as String,
      subscriptionStart: DateTime.parse(json['subscriptionStart'] as String),
      subscriptionEnd: DateTime.parse(json['subscriptionEnd'] as String),
      planType: PlanType.values.firstWhere(
        (e) => e.name == json['planType'],
        orElse: () => PlanType.daily,
      ),
      referredBy: json['referredBy'] as String?,
      referralRewardApplied: json['referralRewardApplied'] != null
          ? DateTime.parse(json['referralRewardApplied'] as String)
          : null,
    )
      ..id = id
      ..lastModified = DateTime.parse(json['lastModified'] as String);
  }

  // Copy with method for updates
  Customer copyWith({
    String? name,
    String? contact,
    bool? isActive,
    String? wifiName,
    String? currentPassword,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    PlanType? planType,
  }) {
    return Customer(
      name: name ?? this.name,
      contact: contact ?? this.contact,
      isActive: isActive ?? this.isActive,
      wifiName: wifiName ?? this.wifiName,
      currentPassword: currentPassword ?? this.currentPassword,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      planType: planType ?? this.planType,
    )
      ..id = id
      ..lastModified = DateTime.now();
  }

  static const int _minLength = 4;

  /// The maximum length for single-word WiFi names
  static const int _maxSingleWordLength = 6;

  /// The minimum random number to append (inclusive)
  static const int _minRandomSuffix = 100;

  /// The maximum random number to append (exclusive)
  static const int _maxRandomSuffix = 999;

  /// Generates a WiFi network name from a customer's name.
  ///
  /// The generated name follows these rules:
  /// - For single-word names:
  ///   * Uses up to 6 characters of the word
  ///   * Adds random numbers if result is too short
  /// - For multiple-word names:
  ///   * Uses first letter of each word
  ///   * Adds random numbers if result is too short
  ///
  /// All special characters are removed and the result is converted to uppercase.
  ///
  /// Parameters:
  ///   customerName: The customer's name to base the WiFi name on
  ///
  /// Returns:
  ///   A generated WiFi network name
  ///
  /// Throws:
  ///   ArgumentError if customerName is null or empty
  static String generateWifiName(String? customerName) {
    // Validate input
    if (customerName == null || customerName.trim().isEmpty) {
      throw ArgumentError('Customer name cannot be null or empty');
    }

    // Remove special characters and extra spaces
    final cleanName = customerName
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Split into words and filter out empty strings
    final words =
        cleanName.split(' ').where((word) => word.isNotEmpty).toList();

    if (words.isEmpty) {
      throw ArgumentError('Customer name contains no valid characters');
    }

    String wifiName;
    if (words.length == 1) {
      wifiName = _generateSingleWordName(words[0]);
    } else {
      wifiName = _generateMultiWordName(words);
    }

    // Ensure minimum length by adding random numbers if necessary
    if (wifiName.length < _minLength) {
      wifiName += _generateRandomSuffix();
    }

    return wifiName.toUpperCase();
  }

  /// Generates a WiFi name from a single word
  static String _generateSingleWordName(String word) {
    if (word.length <= _maxSingleWordLength) {
      return word;
    }
    return word.substring(0, _maxSingleWordLength);
  }

  /// Generates a WiFi name from multiple words using their initials
  static String _generateMultiWordName(List<String> words) {
    return words.where((word) => word.isNotEmpty).map((word) => word[0]).join();
  }

  /// Generates a random numeric suffix for short WiFi names
  static String _generateRandomSuffix() {
    final random = DateTime.now().millisecondsSinceEpoch %
            (_maxRandomSuffix - _minRandomSuffix) +
        _minRandomSuffix;
    return random.toString();
  }

  static const String _upperCaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lowerCaseLetters = 'abcdefghijklmnopqrstuvwxyz';
  static const String _numbers = '0123456789';
  static const String _specialCharacters = '!@#\$%^&*()-_=+';

  /// Default password length
  static const int _defaultLength = 12;

  /// Minimum allowed password length
  static const int _minLengthx = 8;

  /// Maximum allowed password length for practical purposes
  static const int _maxLength = 128;

  /// Generates a cryptographically secure random password.
  ///
  /// Parameters:
  ///   length: Length of the password (default: 12)
  ///   useSpecialChars: Include special characters (default: true)
  ///   useLowerCase: Include lowercase letters (default: true)
  ///   useNumbers: Include numbers (default: true)
  ///
  /// Returns:
  ///   A randomly generated password meeting the specified criteria
  ///
  /// Throws:
  ///   ArgumentError if length is less than 8 or greater than 128
  static String generate({
    int length = _defaultLength,
    bool useSpecialChars = false,
    bool useLowerCase = true,
    bool useNumbers = true,
  }) {
    // Validate input
    if (length < _minLengthx || length > _maxLength) {
      throw ArgumentError(
        'Password length must be between $_minLengthx and $_maxLength characters',
      );
    }

    // Build character pool based on requirements
    final charPool = StringBuffer(_upperCaseLetters);
    if (useLowerCase) charPool.write(_lowerCaseLetters);
    if (useNumbers) charPool.write(_numbers);
    if (useSpecialChars) charPool.write(_specialCharacters);

    final String chars = charPool.toString();
    if (chars.isEmpty) {
      throw ArgumentError('At least one character set must be enabled');
    }

    // Use crypto-secure Random
    final random = Random.secure();
    final password = StringBuffer();

    // Ensure at least one character from each enabled set
    if (useSpecialChars) {
      password.write(
        _specialCharacters[random.nextInt(_specialCharacters.length)],
      );
    }
    if (useLowerCase) {
      password.write(
        _lowerCaseLetters[random.nextInt(_lowerCaseLetters.length)],
      );
    }
    if (useNumbers) {
      password.write(_numbers[random.nextInt(_numbers.length)]);
    }
    password.write(_upperCaseLetters[random.nextInt(_upperCaseLetters.length)]);

    // Fill remaining length with random characters
    final remainingLength = length - password.length;
    for (var i = 0; i < remainingLength; i++) {
      password.write(chars[random.nextInt(chars.length)]);
    }

    // Shuffle the password to avoid predictable character positions
    final passwordChars = password.toString().split('');
    passwordChars.shuffle(random);

    return passwordChars.join();
  }

  /// Checks if a password meets minimum strength requirements.
  ///
  /// Returns:
  ///   true if password meets all requirements, false otherwise
  static bool isStrong(String password) {
    if (password.length < _minLengthx) return false;

    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = password.contains(RegExp(r'[!@#\$%^&*()-_=+]'));

    return hasUpperCase && hasLowerCase && hasNumbers && hasSpecialChars;
  }
}

String _generateReferralCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return String.fromCharCodes(
    List.generate(6, (index) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}
// extension StringExtension on String {
//   dynamic let(Function(String) fn) => fn(this);
// }