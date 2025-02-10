import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String _firstTimeKey = 'isFirstTime';

  // Check if it's the first time using the app
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeKey) ?? true;
  }

  // Mark the app as not first-time
  static Future<void> setNotFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeKey, false);
  }
}

