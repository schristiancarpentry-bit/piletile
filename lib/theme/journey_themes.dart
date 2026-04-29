import 'package:flutter/material.dart';

class JourneyTheme {
  final int id;
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color accentColor;
  final Color bgColor;
  final int bonfireEvery; // 0 = none, -1 = random
  final bool noBonfires;

  const JourneyTheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.accentColor,
    required this.bgColor,
    this.bonfireEvery = 3,
    this.noBonfires = false,
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
    bonfireEvery: 3,
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
  JourneyTheme(
    id: 4,
    name: 'Storm',
    emoji: '⚡',
    primaryColor: Color(0xFF9B59B6),
    accentColor: Color(0xFFFFFF00),
    bgColor: Color(0xFF0A0A1A),
    bonfireEvery: 6,
  ),
  JourneyTheme(
    id: 5,
    name: 'Jungle',
    emoji: '🌿',
    primaryColor: Color(0xFF228B22),
    accentColor: Color(0xFF90EE90),
    bgColor: Color(0xFF071A07),
    bonfireEvery: 7,
  ),
  JourneyTheme(
    id: 6,
    name: 'Deep Sea',
    emoji: '🌊',
    primaryColor: Color(0xFF006994),
    accentColor: Color(0xFF00BFFF),
    bgColor: Color(0xFF00050F),
    bonfireEvery: 8,
  ),
  JourneyTheme(
    id: 7,
    name: 'Space',
    emoji: '🚀',
    primaryColor: Color(0xFF483D8B),
    accentColor: Color(0xFFE0E0FF),
    bgColor: Color(0xFF000005),
    bonfireEvery: 9,
  ),
  JourneyTheme(
    id: 8,
    name: 'Volcano',
    emoji: '🌋',
    primaryColor: Color(0xFF8B0000),
    accentColor: Color(0xFFFF6600),
    bgColor: Color(0xFF0F0000),
    bonfireEvery: 10,
  ),
  JourneyTheme(
    id: 9,
    name: 'Haunted',
    emoji: '👻',
    primaryColor: Color(0xFF6A0DAD),
    accentColor: Color(0xFFB0B0B0),
    bgColor: Color(0xFF080010),
    bonfireEvery: -1, // random
  ),
  JourneyTheme(
    id: 10,
    name: 'Cyber',
    emoji: '🤖',
    primaryColor: Color(0xFF00FF41),
    accentColor: Color(0xFF0080FF),
    bgColor: Color(0xFF000D00),
    noBonfires: true,
  ),
];

JourneyTheme getJourneyTheme(int journeyId) {
  return kJourneys.firstWhere(
    (j) => j.id == journeyId,
    orElse: () => kJourneys[0],
  );
}

bool isBonfireLevel(int journeyId, int level, int? randomBonfireLevel) {
  final theme = getJourneyTheme(journeyId);
  if (theme.noBonfires) return false;
  if (theme.bonfireEvery == -1) {
    return level == randomBonfireLevel;
  }
  return level % theme.bonfireEvery == 0 && level < 13;
}
