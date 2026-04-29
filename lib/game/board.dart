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

  Board({this.columns = 8, this.rows = 5}) {
    grid = List.generate(rows, (_) => List.generate(columns, (_) => TileStack()));
  }

  TileStack stackAt(int col, int row) => grid[row][col];

  List<(int, int)> get allPositions {
    final positions = <(int, int)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        positions.add((c, r));
      }
    }
    return positions;
  }

  (int, int) randomPosition(Random rng) {
    return (rng.nextInt(columns), rng.nextInt(rows));
  }

  void placeTile(Tile tile, int col, int row) {
    grid[row][col].push(tile);
  }

  List<(int, int, Tile)> get tappableTiles {
    final result = <(int, int, Tile)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final top = grid[r][c].top;
        if (top != null && !top.isFrosted && !top.isMatched) {
          result.add((c, r, top));
        }
      }
    }
    return result;
  }

  bool trySelectOrMatch(int col, int row, {required void Function(Tile, Tile) onMatch, required void Function(Tile) onWrongTap}) {
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

    final isMatch = wildcardActive || (prev.pairId == top.pairId && prev.colorIndex == top.colorIndex);

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
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        if (!grid[r][c].isEmpty) return false;
      }
    }
    return true;
  }

  void collapseAllToSingleLayer() {
    final allTiles = <Tile>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final stack = grid[r][c];
        while (!stack.isEmpty) {
          final t = stack.pop();
          if (t != null) allTiles.add(t);
        }
      }
    }
    final rng = Random();
    allTiles.shuffle(rng);
    int idx = 0;
    for (int r = 0; r < rows && idx < allTiles.length; r++) {
      for (int c = 0; c < columns && idx < allTiles.length; c++) {
        grid[r][c].push(allTiles[idx++]);
      }
    }
  }

  void scrambleBuriedTiles(int count) {
    final buried = <(int, int)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        if (grid[r][c].length > 1) buried.add((c, r));
      }
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
