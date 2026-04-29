import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/piletile_game.dart';
import '../managers/level_manager.dart';

class GameScreen extends StatefulWidget {
  final int journeyId;
  final int level;
  final VoidCallback onSuddenDeath;
  final VoidCallback onLevelComplete;

  const GameScreen({
    super.key,
    required this.journeyId,
    required this.level,
    required this.onSuddenDeath,
    required this.onLevelComplete,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late PileTileGame _game;
  GamePhase _phase = GamePhase.dropping;
  int _round = 1;
  int _ceiling = 10;
  double _timer = 0;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _ceiling = LevelManager.pairCeiling(widget.level);
    _game = PileTileGame(
      journeyId: widget.journeyId,
      level: widget.level,
      onPhaseChange: (phase, data) {
        if (mounted) {
          setState(() {
            _phase = phase;
            _round = data['round'] as int? ?? _round;
            _ceiling = data['ceiling'] as int? ?? _ceiling;
            _timer = (data['timer'] as double?) ?? _timer;
            _countdown = (data['countdown'] as int?) ?? _countdown;
          });
        }
      },
      onSuddenDeath: widget.onSuddenDeath,
      onLevelComplete: widget.onLevelComplete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(game: _game),
          _buildHUD(),
          if (_phase == GamePhase.dropping) _buildDroppingOverlay(),
          if (_phase == GamePhase.countdown) _buildCountdownOverlay(),
          if (_phase == GamePhase.roundComplete) _buildRoundCompleteOverlay(),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _HudChip(label: 'L${widget.level}', sub: 'LEVEL'),
            const SizedBox(width: 12),
            _HudChip(label: '$_round / $_ceiling', sub: 'ROUND'),
            const Spacer(),
            if (_phase == GamePhase.matchWindow) ...[
              _TimerBar(remaining: _timer, total: LevelManager.matchWindowSeconds(_round)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDroppingOverlay() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('ROUND $_round — DROPPING...', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 2)),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Center(
      child: Text(
        '$_countdown',
        style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 30)]),
      ),
    );
  }

  Widget _buildRoundCompleteOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
        child: Text('ROUND $_round CLEAR!', style: const TextStyle(color: Color(0xFF50C878), fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final String sub;
  const _HudChip({required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}

class _TimerBar extends StatelessWidget {
  final double remaining;
  final double total;
  const _TimerBar({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    final frac = (remaining / total).clamp(0.0, 1.0);
    final color = frac > 0.5 ? const Color(0xFF50C878) : frac > 0.25 ? const Color(0xFFFFD700) : Colors.red;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(remaining.toStringAsFixed(1), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        SizedBox(
          width: 120,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: frac, backgroundColor: const Color(0xFF222222), valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
      ],
    );
  }
}
