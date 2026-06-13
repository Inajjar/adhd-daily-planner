import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  const TutorialService._();

  static const String _prefix = 'tutorial_';

  static Future<bool> hasSeenTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix${tutorialId}_seen') ?? false;
  }

  static Future<void> markTutorialSeen(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix${tutorialId}_seen', true);
  }

  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
