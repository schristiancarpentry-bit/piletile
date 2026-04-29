import 'tile.dart';

class TileStack {
  final List<Tile> _tiles = [];

  int get length => _tiles.length;
  bool get isEmpty => _tiles.isEmpty;

  Tile? get top => _tiles.isEmpty ? null : _tiles.last;
  Tile? get second => _tiles.length < 2 ? null : _tiles[_tiles.length - 2];

  void push(Tile tile) => _tiles.add(tile);

  Tile? pop() {
    if (_tiles.isEmpty) return null;
    return _tiles.removeLast();
  }

  int get hiddenCount => (_tiles.length - 2).clamp(0, 999);

  List<Tile> get visibleTiles {
    if (_tiles.isEmpty) return [];
    if (_tiles.length == 1) return [_tiles.last];
    return [_tiles[_tiles.length - 2], _tiles.last];
  }

  void swapTopWith(TileStack other) {
    if (isEmpty || other.isEmpty) return;
    final myTop = _tiles.removeLast();
    final theirTop = other._tiles.removeLast();
    _tiles.add(theirTop);
    other._tiles.add(myTop);
  }

  Tile? tileAt(int depth) {
    final idx = _tiles.length - 1 - depth;
    if (idx < 0) return null;
    return _tiles[idx];
  }
}
