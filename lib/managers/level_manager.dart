import 'dart:math';

class LevelManager {
  static int pairCeiling(int level) => level * 5 + 5;

  static int roundsToComplete(int level) => pairCeiling(level);

  // Seconds per pair visible on board — visual search time grows with tile density
  static const double _confusionPerPair = 0.15;

  static double matchWindowSeconds(int round, {int level = 1}) {
    final n = round.toDouble();
    final computed = double.parse((n + sqrt(n)).toStringAsFixed(1));
    final confusion = double.parse((n * _confusionPerPair).toStringAsFixed(1));
    if (level == 1 && round <= 3) return (computed + confusion) < 5.0 ? 5.0 : (computed + confusion);
    final ceiling = pairCeiling(level);
    final lastTwoBonus = round >= ceiling - 1 ? 1.0 : 0.0;
    if (round >= 8) return computed + confusion + 0.3 + (round == 8 ? 0.1 : (round == 10 ? 0.2 : 0.0)) + lastTwoBonus;
    return computed + confusion + lastTwoBonus;
  }

  // Round to start from on any retry / re-entry after the first attempt.
  // Level 1 is always full ramp (short + tutorial content).
  // All other levels start at ~45% of ceiling so early rounds aren't replayed.
  static int bonfireRound(int level) {
    if (level == 1) return 1;
    return (pairCeiling(level) * 0.45).round().clamp(1, pairCeiling(level) - 2);
  }

  static bool isValidLevel(int level) => level >= 1 && level <= 10;
}
