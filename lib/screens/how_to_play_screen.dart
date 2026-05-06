import 'package:flutter/material.dart';

class HowToPlayScreen extends StatelessWidget {
  final VoidCallback onClose;
  const HowToPlayScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_menu_portrait.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1208)),
          ),
          Container(color: Colors.black.withValues(alpha: 0.72)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'HOW TO PLAY',
                  style: TextStyle(
                    color: Color(0xFFFFCC00),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Container(height: 2, width: 160, color: const Color(0xFFE07B00)),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Section(
                          icon: '🟡',
                          title: 'MATCH THE TILES',
                          body:
                              'Pairs of tiles drop onto the board. Tap one tile, then tap its matching partner before time runs out.',
                        ),
                        _Section(
                          icon: '⏳',
                          title: 'BEAT THE CLOCK',
                          body:
                              'Each match has a timer. Rounds get longer as more pairs appear — but a wrong tap resets your window, so stay sharp.',
                        ),
                        _Section(
                          icon: '💀',
                          title: 'THE PILE',
                          body:
                              'Unmatched tiles crash onto the pile at the bottom. Let it grow too tall and it\'s Game Over.',
                        ),
                        _Section(
                          icon: '⭐',
                          title: 'WILDCARD',
                          body:
                              'Matches any tile on the board. Use it to escape a sticky situation.',
                        ),
                        _Section(
                          icon: '🌀',
                          title: 'CHAOS TILE',
                          body:
                              'Scrambles the board when matched. Stay calm — your pairs are still out there.',
                        ),
                        _Section(
                          icon: '🐢',
                          title: 'SLOW-MO',
                          body:
                              'Slows the match timer down for a brief window. Breathe.',
                        ),
                        _Section(
                          icon: '💀',
                          title: 'SKULL',
                          body:
                              'Bad news. Matching a skull pair punishes the pile and drains your time. Avoid them if you can.',
                        ),
                        _Section(
                          icon: '🔥',
                          title: 'BONFIRE LEVELS',
                          body:
                              'Survive a bonfire level and earn a Revive Stone — your safety net if things go wrong later.',
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFFFCC00), width: 2),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Text(
                        'GOT IT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFCC00),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
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

class _Section extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFCC00),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD4B870),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
