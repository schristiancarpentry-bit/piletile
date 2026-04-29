import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LevelCompleteScreen extends StatelessWidget {
  final int level;
  final int pairsCleared;
  final int roundsSurvived;
  final int wrongTaps;
  final VoidCallback onNextLevel;
  final VoidCallback onJourneyMap;

  const LevelCompleteScreen({
    super.key,
    required this.level,
    required this.pairsCleared,
    required this.roundsSurvived,
    required this.wrongTaps,
    required this.onNextLevel,
    required this.onJourneyMap,
  });

  int get stars {
    if (wrongTaps == 0) return 3;
    if (wrongTaps <= 3) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('LEVEL COMPLETE', style: TextStyle(color: Color(0xFF50C878), fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 4))
                .animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '★',
                  style: TextStyle(
                    fontSize: 40,
                    color: i < stars ? const Color(0xFFFFD700) : const Color(0xFF333333),
                    shadows: i < stars ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 12)] : [],
                  ),
                ).animate(delay: (200 * i).ms).scale(begin: const Offset(0, 0), end: const Offset(1, 1)),
              )),
            ),
            const SizedBox(height: 32),
            _StatRow(label: 'Level', value: '$level'),
            _StatRow(label: 'Pairs cleared', value: '$pairsCleared'),
            _StatRow(label: 'Rounds survived', value: '$roundsSurvived'),
            _StatRow(label: 'Wrong taps', value: '$wrongTaps'),
            const SizedBox(height: 40),
            _ActionButton(label: 'NEXT LEVEL', onTap: onNextLevel, primary: true),
            const SizedBox(height: 12),
            _ActionButton(label: 'JOURNEY MAP', onTap: onJourneyMap),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 160, child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 13))),
          const SizedBox(width: 16),
          SizedBox(width: 80, child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _ActionButton({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF50C878) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primary ? const Color(0xFF50C878) : const Color(0xFF333333), width: 1.5),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: primary ? Colors.black : Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 2)),
      ),
    );
  }
}
