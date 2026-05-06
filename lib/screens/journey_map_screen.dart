import 'package:flutter/material.dart';
import '../managers/audio_manager.dart';
import '../managers/ad_manager.dart';
import '../managers/progress_manager.dart';
import '../theme/journey_themes.dart';

const List<int> _kJourneyIds = [1, 2, 3];

class JourneyMapScreen extends StatefulWidget {
  final void Function(int journeyId) onJourneySelected;
  final VoidCallback onBack;
  const JourneyMapScreen({super.key, required this.onJourneySelected, required this.onBack});

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  final _progress = ProgressManager();
  final _audio = AudioManager();

  @override
  void initState() {
    super.initState();
    _audio.playLevelScreenMusic();
  }

  @override
  void dispose() {
    _audio.stopLevelScreenMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // New portrait background
          Image.asset(
            'assets/images/backgrounds/levelselect_portrait.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/level_screen_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.04)),

          SafeArea(
            child: Column(
              children: [
                // ── Back button (standalone, clear of background title) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        _audio.stopLevelScreenMusic();
                        widget.onBack();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD4A76A).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFD4A76A), size: 18),
                      ),
                    ),
                  ),
                ),

                // Push cards below the background logo art (≈38% of screen)
                SizedBox(height: MediaQuery.of(context).size.height * 0.30),

                // Section label above cards
                const Padding(
                  padding: EdgeInsets.only(left: 28, bottom: 8),
                  child: Text(
                    'CHOOSE JOURNEY',
                    style: TextStyle(
                      color: Color(0xFFD4A76A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 3,
                    ),
                  ),
                ),

                // ── Journey cards ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    itemCount: _kJourneyIds.length,
                    itemBuilder: (ctx, i) {
                      final id = _kJourneyIds[i];
                      return _JourneyCard(
                        journeyId: id,
                        unlocked: _progress.isJourneyUnlocked(id),
                        currentLevel: _progress.getCurrentLevel(id),
                        highestLevel: _progress.getHighestLevel(id),
                        onTap: () {
                          _audio.stopLevelScreenMusic();
                          widget.onJourneySelected(id);
                        },
                      );
                    },
                  ),
                ),

                // ── Ad banner pinned at bottom ──
                const BannerAdWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final int journeyId;
  final bool unlocked;
  final int currentLevel;
  final int highestLevel;
  final VoidCallback onTap;

  const _JourneyCard({
    required this.journeyId,
    required this.unlocked,
    required this.currentLevel,
    required this.highestLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = getJourneyTheme(journeyId);
    final progress = (highestLevel / 10.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: unlocked
              ? theme.bgColor.withValues(alpha: 0.88)
              : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked
                ? theme.accentColor.withValues(alpha: 0.75)
                : Colors.white12,
            width: unlocked ? 2.0 : 1.0,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: unlocked
                      ? theme.accentColor.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: unlocked
                        ? theme.accentColor.withValues(alpha: 0.5)
                        : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: unlocked
                      ? _journeyIcon(journeyId)
                      : const Icon(Icons.lock_rounded, color: Colors.white30, size: 28),
                ),
              ),

              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.name.toUpperCase(),
                      style: TextStyle(
                        color: unlocked ? theme.accentColor : Colors.white30,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (unlocked) ...[
                      Text(
                        'Level $currentLevel / 10',
                        style: TextStyle(
                          color: theme.accentColor.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(theme.accentColor),
                          minHeight: 5,
                        ),
                      ),
                    ] else ...[
                      Text(
                        journeyId > 1
                            ? 'Complete ${getJourneyTheme(journeyId - 1).name} to unlock'
                            : 'Locked',
                        style: TextStyle(
                          color: theme.accentColor.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Play button
              if (unlocked) ...[
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 30),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeyIcon(int id) {
    // Try to use journey icon image, fall back to emoji
    return ClipOval(
      child: Image.asset(
        'assets/images/journey_icons/journey_$id.png',
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(
          getJourneyTheme(id).emoji,
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}
