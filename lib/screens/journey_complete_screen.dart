import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/journey_themes.dart';

class JourneyCompleteScreen extends StatelessWidget {
  final int journeyId;
  final VoidCallback onContinue;

  const JourneyCompleteScreen({super.key, required this.journeyId, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final journey = getJourneyTheme(journeyId);
    final next = journeyId < 10 ? getJourneyTheme(journeyId + 1) : null;

    return Scaffold(
      backgroundColor: journey.bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(journey.emoji, style: const TextStyle(fontSize: 64)).animate().scale(duration: 600.ms),
            const SizedBox(height: 16),
            Text('${journey.name.toUpperCase()} COMPLETE', style: TextStyle(color: journey.accentColor, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4))
                .animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 12),
            const Text('All 13 levels cleared.', style: TextStyle(color: Colors.white54, fontSize: 16)),
            if (next != null) ...[
              const SizedBox(height: 32),
              Text('Next: ${next.emoji} ${next.name}', style: TextStyle(color: next.primaryColor, fontWeight: FontWeight.w700, fontSize: 18)),
            ],
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onContinue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: journey.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('CONTINUE', style: TextStyle(color: journey.bgColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
