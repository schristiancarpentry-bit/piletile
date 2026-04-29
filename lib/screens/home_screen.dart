import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../managers/audio_manager.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onPlay;
  const HomeScreen({super.key, required this.onPlay});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _particleController;
  final List<_Particle> _particles = [];
  final _audio = AudioManager();

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    final rng = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.02 + rng.nextDouble() * 0.04,
        size: 1.5 + rng.nextDouble() * 3,
        color: [
          const Color(0xFF50C878),
          const Color(0xFF0F52BA),
          const Color(0xFFFFD700),
          const Color(0xFF9B59B6),
        ][rng.nextInt(4)].withOpacity(0.4 + rng.nextDouble() * 0.4),
      ));
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: AnimatedBuilder(
        animation: _particleController,
        builder: (context, _) {
          for (final p in _particles) {
            p.y -= p.speed * 0.016;
            if (p.y < 0) p.y = 1.0;
          }
          return Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _ParticlePainter(_particles),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PILETILE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 20), Shadow(color: Color(0xFFFFD700), blurRadius: 40)],
                      ),
                    ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.8, end: 1.0),
                    const SizedBox(height: 8),
                    const Text('STACK. MATCH. SURVIVE.', style: TextStyle(color: Color(0xFF888888), fontSize: 14, letterSpacing: 4)),
                    const SizedBox(height: 60),
                    _MenuButton(label: 'PLAY', onTap: widget.onPlay, primary: true),
                    const SizedBox(height: 16),
                    _MenuButton(
                      label: _audio.soundEnabled ? 'SOUND ON' : 'SOUND OFF',
                      onTap: () {
                        setState(() => _audio.toggleSound());
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  double x, y, speed, size;
  Color color;
  _Particle({required this.x, required this.y, required this.speed, required this.size, required this.color});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        Paint()..color = p.color,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _MenuButton({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFFFD700) : const Color(0xFF222222),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primary ? const Color(0xFFFFD700) : const Color(0xFF444444), width: 1.5),
          boxShadow: primary ? [const BoxShadow(color: Color(0x60FFD700), blurRadius: 16, spreadRadius: 2)] : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primary ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
