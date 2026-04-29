import 'package:flutter/material.dart';
import '../managers/progress_manager.dart';
import '../managers/level_manager.dart';
import '../theme/journey_themes.dart';

class LevelMapScreen extends StatefulWidget {
  final int journeyId;
  final void Function(int journeyId, int level) onLevelSelected;
  const LevelMapScreen({super.key, required this.journeyId, required this.onLevelSelected});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  final _progress = ProgressManager();

  @override
  Widget build(BuildContext context) {
    final journey = getJourneyTheme(widget.journeyId);
    final currentLevel = _progress.getCurrentLevel(widget.journeyId);

    return Scaffold(
      backgroundColor: journey.bgColor,
      body: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(journey.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text(journey.name.toUpperCase(), style: TextStyle(color: journey.accentColor, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 3)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: 13,
              itemBuilder: (context, i) {
                final lvl = i + 1;
                final ceiling = LevelManager.pairCeiling(lvl);
                final unlocked = lvl <= currentLevel;
                final isCurrentLevel = lvl == currentLevel;
                final randomBonfire = _progress.getRandomBonfireLevel(widget.journeyId);
                final isBonfire = isBonfireLevel(widget.journeyId, lvl, randomBonfire);

                return GestureDetector(
                  onTap: unlocked ? () => widget.onLevelSelected(widget.journeyId, lvl) : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isCurrentLevel
                          ? journey.primaryColor.withOpacity(0.25)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrentLevel ? journey.primaryColor : (unlocked ? const Color(0xFF333333) : const Color(0xFF1E1E1E)),
                        width: isCurrentLevel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: unlocked ? 1.0 : 0.3,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: unlocked ? journey.primaryColor : const Color(0xFF222222),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('$lvl', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Level $lvl${isBonfire ? '  🔥' : ''}', style: TextStyle(color: unlocked ? Colors.white : Colors.white30, fontWeight: FontWeight.w700, fontSize: 14)),
                              Text('$ceiling pairs · $ceiling rounds', style: TextStyle(color: unlocked ? Colors.white38 : Colors.white12, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (!unlocked) const Icon(Icons.lock, color: Colors.white24, size: 18),
                        if (isCurrentLevel) Icon(Icons.play_arrow, color: journey.accentColor, size: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
