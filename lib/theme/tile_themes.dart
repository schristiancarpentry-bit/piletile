import 'package:flutter/material.dart';

class TileTheme {
  final String id;
  final String name;
  final List<Color> colors;
  final Color backgroundColor;
  final Color gridColor;

  const TileTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.backgroundColor,
    required this.gridColor,
  });
}

const List<Color> kJewelColors = [
  Color(0xFF50C878), // Emerald
  Color(0xFF0F52BA), // Sapphire
  Color(0xFF9B111E), // Ruby
  Color(0xFF9B59B6), // Amethyst
  Color(0xFFFFD700), // Gold
  Color(0xFFFFC200), // Topaz
  Color(0xFFFF69B4), // Rose
  Color(0xFF008080), // Teal
  Color(0xFFF5F5F5), // Pearl
  Color(0xFFC0C0C0), // Silver
];

const TileTheme kDefaultTheme = TileTheme(
  id: 'default',
  name: 'Stone',
  colors: kJewelColors,
  backgroundColor: Color(0xFF0D0D0D),
  gridColor: Color(0xFF1A1A1A),
);

final Map<String, TileTheme> kAllThemes = {
  'default': kDefaultTheme,
};

TileTheme getTheme(String id) => kAllThemes[id] ?? kDefaultTheme;
