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

  String get _grumlorAsset {
    switch (stars) {
      case 3: return 'assets/images/grumblor/grumblor_lc_3star.png';
      case 2: return 'assets/images/grumblor/grumblor_lc_2star.png';
      default: return 'assets/images/grumblor/grumblor_lc_1star.png';
    }
  }

  String get _grumlorQuote {
    switch (stars) {
      case 3: return '"...Fine. That was something."';
      case 2: return '"Acceptable. Don\'t push it."';
      default: return '"You\'re welcome. I wasn\'t watching."';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background archway
          Positioned.fill(
            child: Image.asset(
              'assets/images/level_complete_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // Dark vignette at bottom for button readability
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: size.height * 0.32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Space for the arch header ("LEVEL COMPLETE" is baked into the bg)
                SizedBox(height: size.height * 0.32),

                // Grumblor pose — warmed to match golden arch light
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Ambient glow pool behind him
                    Container(
                      width: size.width * 0.50,
                      height: size.width * 0.18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAA6800).withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    // Grumblor with warm colour cast to match scene lighting
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.72, 0.10, 0.00, 0, 2,
                        0.00, 0.62, 0.00, 0, -4,
                        0.00, 0.00, 0.48, 0, -8,
                        0.00, 0.00, 0.00, 1,  0,
                      ]),
                      child: Image.asset(
                        _grumlorAsset,
                        width: size.width * 0.55,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    // Ground contact shadow
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: size.width * 0.32,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 18,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .slideY(begin: 0.15, end: 0, duration: 500.ms, delay: 200.ms,
                        curve: Curves.easeOut),

                const SizedBox(height: 14),

                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      '★',
                      style: TextStyle(
                        fontSize: 38,
                        color: i < stars
                            ? const Color(0xFFFFD700)
                            : Colors.white.withValues(alpha: 0.15),
                        shadows: i < stars
                            ? [const Shadow(color: Color(0xFFFFAA00), blurRadius: 16)]
                            : [],
                      ),
                    )
                        .animate(delay: (300 + 150 * i).ms)
                        .scale(begin: const Offset(0.2, 0.2), end: const Offset(1, 1),
                            duration: 400.ms, curve: Curves.elasticOut),
                  )),
                ),

                const SizedBox(height: 12),

                // Grumblor quote
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _grumlorQuote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE8D5A0),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 400.ms),

                const Spacer(),

                // Wrong taps badge (only if non-zero)
                if (wrongTaps > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      wrongTaps == 1 ? '1 wrong tap' : '$wrongTaps wrong taps',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ).animate(delay: 600.ms).fadeIn(),

                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      _LCButton(
                        label: 'NEXT LEVEL',
                        onTap: onNextLevel,
                        primary: true,
                      ).animate(delay: 500.ms).fadeIn(duration: 300.ms)
                          .slideY(begin: 0.2, end: 0, duration: 300.ms),
                      const SizedBox(height: 10),
                      _LCButton(
                        label: 'JOURNEY MAP',
                        onTap: onJourneyMap,
                      ).animate(delay: 600.ms).fadeIn(duration: 300.ms),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LCButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _LCButton({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: primary
              ? const Color(0xFFD4A76A).withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary
                ? const Color(0xFFD4A76A)
                : Colors.white.withValues(alpha: 0.2),
            width: primary ? 2.0 : 1.0,
          ),
          boxShadow: primary
              ? [BoxShadow(color: const Color(0xFFD4A76A).withValues(alpha: 0.3), blurRadius: 14)]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primary ? const Color(0xFFF5E6C0) : Colors.white60,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}
