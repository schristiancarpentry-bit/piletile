import 'package:flutter/material.dart';

class JourneyTheme {
  final int id;
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color accentColor;
  final Color bgColor;
  final int bonfireEvery;

  const JourneyTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.accentColor,
    required this.bgColor,
    this.bonfireEvery = 3,
  });
}

const List<JourneyTheme> kJourneys = [
  JourneyTheme(
    id: 1,
    name: 'Bedrock',
    emoji: '🪨',
    primaryColor: Color(0xFF8B7355),
    accentColor: Color(0xFFD4A76A),
    bgColor: Color(0xFF1A1208),
    bonfireEvery: 2,
  ),
  JourneyTheme(
    id: 2,
    name: 'Blizzard',
    emoji: '❄️',
    primaryColor: Color(0xFF6BA3BE),
    accentColor: Color(0xFFB8D4E3),
    bgColor: Color(0xFF071520),
    bonfireEvery: 4,
  ),
  JourneyTheme(
    id: 3,
    name: 'Inferno',
    emoji: '🔥',
    primaryColor: Color(0xFFFF4500),
    accentColor: Color(0xFFFFAA00),
    bgColor: Color(0xFF1A0500),
    bonfireEvery: 5,
  ),
];

JourneyTheme getJourneyTheme(int journeyId) {
  return kJourneys.firstWhere(
    (j) => j.id == journeyId,
    orElse: () => kJourneys[0],
  );
}

bool isBonfireLevel(int journeyId, int level) {
  if (level <= 0 || level > 10) return false;
  final theme = getJourneyTheme(journeyId);
  return level % theme.bonfireEvery == 0;
}
