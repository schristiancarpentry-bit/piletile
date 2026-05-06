import 'package:flutter/material.dart';

enum Journey { bedrock, blizzard, inferno }

enum JourneyHazard { none, freeze, sink }

class JourneyConfig {
  final int id;
  final Journey journey;
  final String name;
  final String emoji;
  final String backgroundAsset;
  final String tileSheetAsset;
  final Color primaryColour;
  final Color accentColor;
  final Color hudColor;
  final bool unlockedByDefault;
  final JourneyHazard hazard;

  const JourneyConfig({
    required this.id,
    required this.journey,
    required this.name,
    required this.emoji,
    required this.backgroundAsset,
    required this.tileSheetAsset,
    required this.primaryColour,
    required this.accentColor,
    required this.hudColor,
    this.unlockedByDefault = false,
    this.hazard = JourneyHazard.none,
  });
}

const List<JourneyConfig> kJourneyConfigs = [
  JourneyConfig(
    id: 1,
    journey: Journey.bedrock,
    name: 'Bedrock',
    emoji: '🪨',
    backgroundAsset: 'assets/images/backgrounds/bg_bedrock_portrait.png',
    tileSheetAsset: '',
    primaryColour: Color(0xFFD4A855),
    accentColor: Color(0xFFFFD700),
    hudColor: Color(0xFF2C1A00),
    unlockedByDefault: true,
    hazard: JourneyHazard.none,
  ),
  JourneyConfig(
    id: 2,
    journey: Journey.blizzard,
    name: 'Blizzard',
    emoji: '❄️',
    backgroundAsset: 'assets/images/backgrounds/bg_blizzard.jpg',
    tileSheetAsset: 'assets/images/tiles/coldtiles.png',
    primaryColour: Color(0xFF8DD4F5),
    accentColor: Color(0xFF88CCFF),
    hudColor: Color(0xFF001830),
    hazard: JourneyHazard.freeze,
  ),
  JourneyConfig(
    id: 3,
    journey: Journey.inferno,
    name: 'Inferno',
    emoji: '🔥',
    backgroundAsset: 'assets/images/backgrounds/bg_inferno.jpg',
    tileSheetAsset: '',
    primaryColour: Color(0xFFE84C1E),
    accentColor: Color(0xFFFF4400),
    hudColor: Color(0xFF2A0A00),
    hazard: JourneyHazard.sink,
  ),
];

JourneyConfig journeyConfig(int journeyId) {
  final idx = (journeyId - 1).clamp(0, kJourneyConfigs.length - 1);
  return kJourneyConfigs[idx];
}

JourneyConfig journeyConfigByEnum(Journey j) {
  return kJourneyConfigs.firstWhere((c) => c.journey == j);
}
