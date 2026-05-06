import 'dart:math';
import '../game/tile.dart';
import '../game/board.dart';

class RoundManager {
  final Random _rng = Random();

  double _badChance(int round) {
    if (round < 5) return 0.0;
    if (round < 8) return 0.15;
    if (round < 12) return 0.25;
    if (round < 18) return 0.35;
    return 0.45;
  }

  // Each special/bad tile belongs to a category. Only one tile per category
  // can spawn per round — prevents chaos+scramble appearing together (same image),
  // and prevents double skull or double wildcard pairs.
  static String _specialCategory(SpecialTileId id) {
    switch (id) {
      case SpecialTileId.shuffle:  return 'chaos';
      case SpecialTileId.wildcard: return 'wildcard';
      case SpecialTileId.slowMo:   return 'slowmo';
    }
  }

  static String _badCategory(BadTileId id) {
    switch (id) {
      case BadTileId.skull:    return 'skull';
      case BadTileId.scramble: return 'chaos'; // same image as shuffle — same category
    }
  }

  List<(Tile, int, int, Tile, int, int)> generateRound({
    required int pairCount,
    required Board board,
    required int round,
    int level = 1,
  }) {
    final drops = <(Tile, int, int, Tile, int, int)>[];

    final colorIndices = List.generate(10, (i) => i)..shuffle(_rng);
    final badChance = _badChance(round);
    final usedCategories = <String>{};

    for (int i = 0; i < pairCount; i++) {
      final colorIdx = colorIndices[i % 10];
      TileType type = TileType.normal;
      SpecialTileId? specialId;
      BadTileId? badId;

      // FTUE: guaranteed wildcard on level 1 round 3
      if (level == 1 && round == 3 && i == pairCount - 1) {
        type = TileType.special;
        specialId = SpecialTileId.wildcard;
        usedCategories.add('wildcard');
      }
      // Last pair: chance of a special tile (round >= 4)
      else if (round >= 4 && i == pairCount - 1 && _rng.nextDouble() < 0.30) {
        final available = SpecialTileId.values
            .where((id) => !usedCategories.contains(_specialCategory(id)))
            .toList();
        if (available.isNotEmpty) {
          type = TileType.special;
          specialId = available[_rng.nextInt(available.length)];
          usedCategories.add(_specialCategory(specialId));
        }
      }
      // Second-to-last: bad tile scaling with round
      else if (badChance > 0 && i == pairCount - 2 && pairCount >= 3 &&
          _rng.nextDouble() < badChance) {
        final available = BadTileId.values
            .where((id) => !usedCategories.contains(_badCategory(id)))
            .toList();
        if (available.isNotEmpty) {
          type = TileType.bad;
          badId = available[_rng.nextInt(available.length)];
          usedCategories.add(_badCategory(badId));
        }
      }
      // Third-to-last: second bad tile at high rounds (round >= 15)
      else if (round >= 15 && badChance > 0 && i == pairCount - 3 && pairCount >= 5 &&
          _rng.nextDouble() < badChance * 0.6) {
        final available = BadTileId.values
            .where((id) => !usedCategories.contains(_badCategory(id)))
            .toList();
        if (available.isNotEmpty) {
          type = TileType.bad;
          badId = available[_rng.nextInt(available.length)];
          usedCategories.add(_badCategory(badId));
        }
      }

      final tileA = Tile(colorIndex: colorIdx, pairId: i, type: type, specialId: specialId, badId: badId);
      final tileB = Tile(colorIndex: colorIdx, pairId: i, type: type, specialId: specialId, badId: badId);

      final posA = board.randomPosition(_rng);
      var posB = board.randomPosition(_rng);
      while (posB == posA) posB = board.randomPosition(_rng);

      drops.add((tileA, posA.$1, posA.$2, tileB, posB.$1, posB.$2));
    }
    return drops;
  }
}
