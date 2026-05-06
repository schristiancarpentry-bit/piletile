import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../managers/audio_manager.dart';
import 'how_to_play_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onPlay;
  final VoidCallback onStory;
  const HomeScreen({super.key, required this.onPlay, required this.onStory});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _audio = AudioManager();

  @override
  void initState() {
    super.initState();
    _audio.playMenuMusic();
  }

  void _onPlay() {
    _audio.stopMenuMusic();
    widget.onPlay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/backgrounds/bg_menu_portrait.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1208)),
          ),
          Container(color: Colors.black.withValues(alpha: 0.04)),

          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                _MenuButton(label: '▶  PLAY', onTap: _onPlay)
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                _SecondaryButton(
                  label: 'HOW TO PLAY',
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HowToPlayScreen(
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ));
                  },
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 12),

                _SecondaryButton(
                  label: 'THE STORY',
                  onTap: () {
                    _audio.stopMenuMusic();
                    widget.onStory();
                  },
                ).animate().fadeIn(delay: 550.ms),

                const SizedBox(height: 32),

                SizedBox(
                  height: 200,
                  child: Image.asset(
                    'assets/images/grumblor/grumblor_idle.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF9A7833), width: 1.5),
          borderRadius: BorderRadius.circular(40),
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFBB9944),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MenuButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFCC00), Color(0xFFE07B00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFFFEE88), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAAFF9900),
              blurRadius: 16,
              spreadRadius: 2,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Text(
          '▶  PLAY',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
