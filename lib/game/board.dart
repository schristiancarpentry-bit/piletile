import 'dart:math';
import 'tile.dart';
import 'tile_stack.dart';

class Board {
  final int columns;
  final int rows;
  late List<List<TileStack>> grid;
  bool wildcardActive = false;
  Tile? selectedTile;
  int? selectedCol;
  int? selectedRow;

  List<(int, int)> _validPositions = [];

  Board({this.columns = 8, this.rows = 4}) {
    grid = List.generate(rows, (_) => List.generate(columns, (_) => TileStack()));
  }

  void setValidPositions(List<(int, int)> positions) {
    _validPositions = positions;
  }

  bool isValidPosition(int col, int row) {
    if (_validPositions.isEmpty) return col < columns && row < rows;
    return _validPositions.any((p) => p.$1 == col && p.$2 == row);
  }

  TileStack stackAt(int col, int row) => grid[row][col];

  List<(int, int)> get allPositions {
    if (_validPositions.isNotEmpty) return List.from(_validPositions);
    final positions = <(int, int)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        positions.add((c, r));
      }
    }
    return positions;
  }

  (int, int) randomPosition(Random rng) {
    final positions = allPositions;
    return positions[rng.nextInt(positions.length)];
  }

  void placeTile(Tile tile, int col, int row) {
    grid[row][col].push(tile);
  }

  List<(int, int, Tile)> get tappableTiles {
    final result = <(int, int, Tile)>[];
    for (final pos in allPositions) {
      final top = grid[pos.$2][pos.$1].top;
      if (top != null && !top.isFrosted && !top.isMatched) {
        result.add((pos.$1, pos.$2, top));
      }
    }
    return result;
  }

  bool trySelectOrMatch(int col, int row,
      {required void Function(Tile, Tile) onMatch,
      required void Function(Tile) onWrongTap}) {
    if (!isValidPosition(col, row)) return false;
    final stack = stackAt(col, row);
    final top = stack.top;
    if (top == null || top.isFrosted || top.isMatched) return false;

    if (selectedTile == null) {
      selectedTile = top;
      selectedCol = col;
      selectedRow = row;
      return true;
    }

    final prev = selectedTile!;
    final prevCol = selectedCol!;
    final prevRow = selectedRow!;

    if (prevCol == col && prevRow == row) {
      selectedTile = null;
      selectedCol = null;
      selectedRow = null;
      return false;
    }

    final isMatch =
        wildcardActive || (prev.pairId == top.pairId && prev.colorIndex == top.colorIndex);

    if (isMatch) {
      prev.isMatched = true;
      top.isMatched = true;
      stackAt(prevCol, prevRow).pop();
      stack.pop();
      wildcardActive = false;
      selectedTile = null;
      selectedCol = null;
      selectedRow = null;
      onMatch(prev, top);
    } else {
      top.isFlashingRed = true;
      onWrongTap(top);
      selectedTile = null;
      selectedCol = null;
      selectedRow = null;
    }
    return true;
  }

  bool get allMatched {
    for (final pos in allPositions) {
      if (!grid[pos.$2][pos.$1].isEmpty) return false;
    }
    return true;
  }

  int get tileCount {
    int count = 0;
    for (final pos in allPositions) {
      count += grid[pos.$2][pos.$1].length;
    }
    return count;
  }

  void collapseAllToSingleLayer() {
    final positions = allPositions;
    final allTiles = <Tile>[];
    for (final pos in positions) {
      final stack = grid[pos.$2][pos.$1];
      while (!stack.isEmpty) {
        final t = stack.pop();
        if (t != null) allTiles.add(t);
      }
    }
    final rng = Random();
    allTiles.shuffle(rng);

    // Place tiles back ensuring same-pair tiles never share a cell.
    // Without this check, both tiles of a pair can land on the same position,
    // making them impossible to match (tapping the same cell twice deselects).
    final cellTopPairId = List<int?>.filled(positions.length, null);
    for (int i = 0; i < allTiles.length; i++) {
      final tile = allTiles[i];
      int idx = i % positions.length;
      if (cellTopPairId[idx] == tile.pairId) {
        for (int d = 1; d < positions.length; d++) {
          final alt = (idx + d) % positions.length;
          if (cellTopPairId[alt] != tile.pairId) {
            idx = alt;
            break;
          }
        }
      }
      grid[positions[idx].$2][positions[idx].$1].push(tile);
      cellTopPairId[idx] = tile.pairId;
    }
  }

  void scrambleBuriedTiles(int count) {
    final buried = <(int, int)>[];
    for (final pos in allPositions) {
      if (grid[pos.$2][pos.$1].length > 1) buried.add(pos);
    }
    if (buried.length < 2) return;
    final rng = Random();
    buried.shuffle(rng);
    final toSwap = buried.take(count.clamp(2, buried.length)).toList();
    for (int i = 0; i < toSwap.length - 1; i += 2) {
      final a = toSwap[i];
      final b = toSwap[i + 1];
      grid[a.$2][a.$1].swapTopWith(grid[b.$2][b.$1]);
    }
  }

  void clearAll() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        grid[r][c] = TileStack();
      }
    }
    wildcardActive = false;
    selectedTile = null;
    selectedCol = null;
    selectedRow = null;
  }
}
