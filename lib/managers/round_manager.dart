import 'dart:math';
import '../game/tile.dart';
import '../game/board.dart';

class RoundManager {
  final Random _rng = Random();

  List<(Tile, int, int, Tile, int, int)> generateRound({
    required int pairCount,
    required Board board,
    required int round,
  }) {
    final drops = <(Tile, int, int, Tile, int, int)>[];
    for (int i = 0; i < pairCount; i++) {
      final colorIdx = _rng.nextInt(10);
      TileType type = TileType.normal;
      SpecialTileId? specialId;
      BadTileId? badId;

      if (round >= 4 && i == pairCount - 1 && _rng.nextDouble() < 0.3) {
        type = TileType.special;
        specialId = SpecialTileId.values[_rng.nextInt(SpecialTileId.values.length)];
      } else if (round >= 6 && i == pairCount - 2 && _rng.nextDouble() < 0.25) {
        type = TileType.bad;
        badId = BadTileId.values[_rng.nextInt(BadTileId.values.length)];
      }

      final tileA = Tile(colorIndex: colorIdx, pairId: i, type: type, specialId: specialId, badId: badId);
      final tileB = Tile(colorIndex: colorIdx, pairId: i, type: type, specialId: specialId, badId: badId);

      final posA = board.randomPosition(_rng);
      var posB = board.randomPosition(_rng);
      while (posB == posA) {
        posB = board.randomPosition(_rng);
      }

      drops.add((tileA, posA.$1, posA.$2, tileB, posB.$1, posB.$2));
    }
    return drops;
  }
}
