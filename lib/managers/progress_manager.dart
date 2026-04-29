import 'package:shared_preferences/shared_preferences.dart';

class ProgressManager {
  static final ProgressManager _instance = ProgressManager._();
  factory ProgressManager() => _instance;
  ProgressManager._();

  late SharedPreferences _prefs;
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _prefs = await SharedPreferences.getInstance();
    _initialised = true;
  }

  int getCurrentLevel(int journeyId) => _prefs.getInt('j${journeyId}_level') ?? 1;
  int getBonfireLevel(int journeyId) => _prefs.getInt('j${journeyId}_bonfire') ?? 1;
  int getHighestLevel(int journeyId) => _prefs.getInt('j${journeyId}_highest') ?? 0;
  bool isJourneyUnlocked(int journeyId) {
    if (journeyId <= 1) return true;
    if (journeyId == 2) return getHighestLevel(1) >= 13;
    return getHighestLevel(journeyId - 1) >= 13;
  }
  String getActiveTheme() => _prefs.getString('active_theme') ?? 'default';
  List<String> getUnlockedThemes() => _prefs.getStringList('unlocked_themes') ?? ['default'];
  int? getRandomBonfireLevel(int journeyId) {
    final v = _prefs.getInt('j${journeyId}_random_bonfire');
    return v;
  }

  Future<void> saveCurrentLevel(int journeyId, int level) async {
    await _prefs.setInt('j${journeyId}_level', level);
    final highest = getHighestLevel(journeyId);
    if (level - 1 > highest) {
      await _prefs.setInt('j${journeyId}_highest', level - 1);
    }
  }

  Future<void> saveBonfire(int journeyId, int level) async {
    await _prefs.setInt('j${journeyId}_bonfire', level);
  }

  Future<void> saveHighestLevel(int journeyId, int level) async {
    final current = getHighestLevel(journeyId);
    if (level > current) await _prefs.setInt('j${journeyId}_highest', level);
  }

  Future<void> saveActiveTheme(String themeId) async {
    await _prefs.setString('active_theme', themeId);
  }

  Future<void> setRandomBonfireLevel(int journeyId, int level) async {
    await _prefs.setInt('j${journeyId}_random_bonfire', level);
  }

  Future<void> dropToLastBonfire(int journeyId) async {
    final bonfire = getBonfireLevel(journeyId);
    await saveCurrentLevel(journeyId, bonfire);
  }
}
