import 'package:flutter/material.dart';

enum TileType { normal, special, bad }

enum SpecialTileId { slowMo, wildcard, shuffle }

enum BadTileId { skull, scramble }

class Tile {
  final int colorIndex;
  final TileType type;
  final SpecialTileId? specialId;
  final BadTileId? badId;
  final int pairId;

  bool isFrosted = false;
  bool isMatched = false;
  bool isFlashingRed = false;

  Tile({
    required this.colorIndex,
    required this.pairId,
    this.type = TileType.normal,
    this.specialId,
    this.badId,
  });

  bool get isSpecial => type == TileType.special;
  bool get isBad => type == TileType.bad;

  Color get baseColor {
    const colors = [
      Color(0xFF50C878),
      Color(0xFF0F52BA),
      Color(0xFF9B111E),
      Color(0xFF9B59B6),
      Color(0xFFFFD700),
      Color(0xFFFFC200),
      Color(0xFFFF69B4),
      Color(0xFF008080),
      Color(0xFFF5F5F5),
      Color(0xFFC0C0C0),
    ];
    return colors[colorIndex % colors.length];
  }

  String get symbol {
    if (isSpecial) {
      switch (specialId) {
        case SpecialTileId.slowMo: return '⏳';
        case SpecialTileId.wildcard: return '✨';
        case SpecialTileId.shuffle: return '🔀';
        default: return '★';
      }
    }
    if (isBad) {
      switch (badId) {
        case BadTileId.skull: return '💀';
        case BadTileId.scramble: return '🌀';
        default: return '✖';
      }
    }
    const symbols = ['◆', '●', '▲', '★', '♦', '♥', '♣', '♠', '⬟', '⬡'];
    return symbols[colorIndex % symbols.length];
  }
}
