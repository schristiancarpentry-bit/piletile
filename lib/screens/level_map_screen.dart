import 'package:flutter/material.dart';
import '../managers/progress_manager.dart';
import '../managers/level_manager.dart';
import '../managers/ad_manager.dart';
import '../theme/journey_themes.dart';

const _kLevelMapBg = <int, String>{
  1: 'assets/images/backgrounds/levelmap_bedrock.png',
  2: 'assets/images/backgrounds/levelmap_bedrock.png',
  3: 'assets/images/backgrounds/levelmap_bedrock.png',
};

class LevelMapScreen extends StatefulWidget {
  final int journeyId;
  final VoidCallback onBack;
  final void Function(int journeyId, int level) onLevelSelected;

  const LevelMapScreen({
    super.key,
    required this.journeyId,
    required this.onBack,
    required this.onLevelSelected,
  });

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  final _progress = ProgressManager();

  @override
  Widget build(BuildContext context) {
    final journey = getJourneyTheme(widget.journeyId);
    final currentLevel = _progress.getCurrentLevel(widget.journeyId);
    final bgAsset = _kLevelMapBg[widget.journeyId];

    return Scaffold(
      backgroundColor: journey.bgColor,
      body: Stack(
        children: [
          if (bgAsset != null)
            Positioned.fill(child: Image.asset(bgAsset, fit: BoxFit.cover)),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.06)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: journey.accentColor.withValues(alpha: 0.6), width: 1.5),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: journey.accentColor, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(journey.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Text(
                        journey.name.toUpperCase(),
                        style: TextStyle(
                          color: journey.accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 3,
                          shadows: [Shadow(
                              color: journey.accentColor.withValues(alpha: 0.5),
                              blurRadius: 12)],
                        ),
                      ),
                    ],
                  ),
                ),
                const Center(child: BannerAdWidget()),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: 10,
                    itemBuilder: (context, i) {
                      final lvl = i + 1;
                      final rounds = LevelManager.pairCeiling(lvl);
                      final unlocked = lvl <= currentLevel;
                      final isCurrent = lvl == currentLevel;
                      final isBonfire = isBonfireLevel(widget.journeyId, lvl);
                      final stars = _progress.getStars(widget.journeyId, lvl);
                      final completed = stars > 0;

                      return GestureDetector(
                        onTap: unlocked
                            ? () => widget.onLevelSelected(widget.journeyId, lvl)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? journey.primaryColor.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent
                                  ? journey.accentColor
                                  : (unlocked
                                      ? journey.primaryColor.withValues(alpha: 0.4)
                                      : Colors.white10),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Opacity(
                                opacity: unlocked ? 1.0 : 0.3,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: unlocked ? journey.primaryColor : Colors.white12,
                                    shape: BoxShape.circle,
                                    boxShadow: unlocked
                                        ? [BoxShadow(
                                            color: journey.primaryColor.withValues(alpha: 0.4),
                                            blurRadius: 8)]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text('$lvl',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Level $lvl${isBonfire ? '  🔥' : ''}',
                                      style: TextStyle(
                                          color: unlocked ? Colors.white : Colors.white30,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      '$rounds rounds',
                                      style: TextStyle(
                                          color: unlocked ? Colors.white38 : Colors.white12,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (completed)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    3,
                                    (si) => Text(
                                      '★',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: si < stars
                                            ? const Color(0xFFFFD700)
                                            : Colors.white12,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (!unlocked)
                                const Icon(Icons.lock_rounded,
                                    color: Colors.white24, size: 18)
                              else if (isCurrent)
                                Icon(Icons.play_arrow_rounded,
                                    color: journey.accentColor, size: 26),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
