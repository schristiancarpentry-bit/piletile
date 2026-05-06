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

  bool get hasSeenTutorial => _prefs.getBool('tutorial_seen') ?? false;
  Future<void> markTutorialSeen() async => _prefs.setBool('tutorial_seen', true);

  int getCurrentLevel(int journeyId) => _prefs.getInt('j${journeyId}_level') ?? 1;
  int getStars(int journeyId, int level) => _prefs.getInt('j${journeyId}_l${level}_stars') ?? 0;
  int getBonfireLevel(int journeyId) => _prefs.getInt('j${journeyId}_bonfire') ?? 1;
  int getHighestLevel(int journeyId) => _prefs.getInt('j${journeyId}_highest') ?? 0;

  bool isJourneyUnlocked(int journeyId) {
    if (journeyId <= 1) return true;
    return getHighestLevel(journeyId - 1) >= 10;
  }

  String getActiveTheme() => _prefs.getString('active_theme') ?? 'default';
  List<String> getUnlockedThemes() => _prefs.getStringList('unlocked_themes') ?? ['default'];

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

  Future<void> saveStars(int journeyId, int level, int stars) async {
    final current = getStars(journeyId, level);
    if (stars > current) await _prefs.setInt('j${journeyId}_l${level}_stars', stars);
  }

  Future<void> saveActiveTheme(String themeId) async {
    await _prefs.setString('active_theme', themeId);
  }

  Future<void> dropToLastBonfire(int journeyId) async {
    final bonfire = getBonfireLevel(journeyId);
    await saveCurrentLevel(journeyId, bonfire);
  }

  int get stoneCount => _prefs.getInt('revive_stones') ?? 0;
  // Bonfire round: tracks whether the player has attempted a level before.
  // First attempt always starts from round 1; subsequent attempts from bonfireRound.
  bool get hasSeenIntro => _prefs.getBool('intro_seen') ?? false;
  Future<void> markIntroSeen() async => _prefs.setBool('intro_seen', true);

  bool hasAttemptedLevel(int journeyId, int level) =>
      _prefs.getBool('j${journeyId}_l${level}_attempted') ?? false;

  Future<void> markLevelAttempted(int journeyId, int level) async =>
      _prefs.setBool('j${journeyId}_l${level}_attempted', true);

  bool get hasReviveStone => stoneCount > 0;

  Future<void> addReviveStone() async {
    final current = stoneCount;
    if (current < 5) await _prefs.setInt('revive_stones', current + 1);
  }

  Future<void> spendReviveStone() async {
    final current = stoneCount;
    if (current > 0) await _prefs.setInt('revive_stones', current - 1);
  }
}
