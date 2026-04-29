import 'tile.dart';
import 'board.dart';

class SpecialTileHandler {
  static void applySpecial(SpecialTileId id, Board board, void Function(double) onSlowMo) {
    switch (id) {
      case SpecialTileId.slowMo:
        onSlowMo(3.0);
        break;
      case SpecialTileId.wildcard:
        board.wildcardActive = true;
        break;
      case SpecialTileId.shuffle:
        board.collapseAllToSingleLayer();
        break;
    }
  }

  static void applyBad(BadTileId id, Board board, void Function(double) onTimePenalty, void Function() onScramble) {
    switch (id) {
      case BadTileId.skull:
        onTimePenalty(-2.0);
        break;
      case BadTileId.scramble:
        board.scrambleBuriedTiles(3);
        onScramble();
        break;
    }
  }
}
