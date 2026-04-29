import 'dart:async';
import 'dart:math';
import '../game/board.dart';
import '../managers/audio_manager.dart';

class HazardManager {
  final int journeyId;
  final Board board;
  final AudioManager audio = AudioManager();
  Timer? _hazardTimer;
  final Random _rng = Random();

  HazardManager({required this.journeyId, required this.board});

  void start(int level) {
    _hazardTimer?.cancel();
    if (journeyId == 1) return; // Bedrock has no hazard
    _hazardTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tick(level));
  }

  void _tick(int level) {
    switch (journeyId) {
      case 2:
        _applyBlizzard(level);
        break;
      default:
        // Stub — hazard pending for journeys 3-10
        return;
    }
  }

  void _applyBlizzard(int level) {
    final maxFreeze = level >= 5 ? 3 : 2;
    final tappable = board.tappableTiles;
    if (tappable.isEmpty) return;
    tappable.shuffle(_rng);
    final toFreeze = tappable.take(min(maxFreeze, tappable.length)).toList();
    for (final (_, _, tile) in toFreeze) {
      tile.isFrosted = true;
    }
    audio.playWind();
    Timer(const Duration(seconds: 3), () {
      for (final (_, _, tile) in toFreeze) {
        tile.isFrosted = false;
      }
    });
  }

  void stop() {
    _hazardTimer?.cancel();
  }

  void dispose() {
    _hazardTimer?.cancel();
  }
}
