import 'package:flutter/material.dart';
import '../managers/progress_manager.dart';
import '../theme/journey_themes.dart';

class JourneyMapScreen extends StatefulWidget {
  final void Function(int journeyId) onJourneySelected;
  const JourneyMapScreen({super.key, required this.onJourneySelected});

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  final _progress = ProgressManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        children: [
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('SELECT JOURNEY', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: kJourneys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (context, i) {
                final journey = kJourneys[i];
                final unlocked = _progress.isJourneyUnlocked(journey.id);
                final highest = _progress.getHighestLevel(journey.id);
                final bonfire = _progress.getBonfireLevel(journey.id);
                return _JourneyNode(
                  journey: journey,
                  unlocked: unlocked,
                  highestLevel: highest,
                  bonfireLevel: bonfire,
                  onTap: unlocked ? () => widget.onJourneySelected(journey.id) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyNode extends StatelessWidget {
  final JourneyTheme journey;
  final bool unlocked;
  final int highestLevel;
  final int bonfireLevel;
  final VoidCallback? onTap;

  const _JourneyNode({
    required this.journey,
    required this.unlocked,
    required this.highestLevel,
    required this.bonfireLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.4,
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked ? journey.primaryColor : const Color(0xFF333333),
              width: 2,
            ),
            boxShadow: unlocked
                ? [BoxShadow(color: journey.primaryColor.withOpacity(0.3), blurRadius: 16, spreadRadius: 1)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(journey.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(journey.name.toUpperCase(), style: TextStyle(color: journey.accentColor, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              const SizedBox(height: 8),
              if (!unlocked)
                const Icon(Icons.lock, color: Colors.white38, size: 24)
              else ...[
                Text('Level $highestLevel / 13', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    Text(' Bonfire L$bonfireLevel', style: const TextStyle(color: Colors.orange, fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
