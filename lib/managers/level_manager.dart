class LevelManager {
  static int pairCeiling(int level) => 5 + level * 5;

  static int roundsToComplete(int level) => pairCeiling(level);

  static double matchWindowSeconds(int pairs) => pairs.toDouble();

  static bool isValidLevel(int level) => level >= 1 && level <= 13;
}
