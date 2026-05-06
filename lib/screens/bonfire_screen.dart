import 'dart:math';
import 'package:flutter/material.dart';

class BonfireScreen extends StatefulWidget {
  final int journeyId;
  final int level;
  final VoidCallback onRest;

  const BonfireScreen(
      {super.key,
      required this.journeyId,
      required this.level,
      required this.onRest});

  @override
  State<BonfireScreen> createState() => _BonfireScreenState();
}

class _BonfireScreenState extends State<BonfireScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Ember> _embers = [];

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    final rng = Random();
    for (int i = 0; i < 60; i++) {
      _embers.add(_Ember(
        x: 0.5 + (rng.nextDouble() - 0.5) * 0.15,
        y: 0.6 + rng.nextDouble() * 0.1,
        vx: (rng.nextDouble() - 0.5) * 0.002,
        vy: -(0.003 + rng.nextDouble() * 0.005),
        size: 1.5 + rng.nextDouble() * 3,
        life: rng.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0500),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          for (final e in _embers) {
            e.x += e.vx;
            e.y += e.vy;
            e.life -= 0.008;
            if (e.life <= 0 || e.y < 0.1) {
              final rng = Random();
              e.x = 0.5 + (rng.nextDouble() - 0.5) * 0.12;
              e.y = 0.62 + rng.nextDouble() * 0.05;
              e.vx = (rng.nextDouble() - 0.5) * 0.002;
              e.vy = -(0.003 + rng.nextDouble() * 0.005);
              e.life = 0.8 + rng.nextDouble() * 0.2;
            }
          }
          return Stack(
            children: [
              CustomPaint(size: Size.infinite, painter: _EmberPainter(_embers)),
              Row(
                children: [
                  // Grumblor
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: SizedBox(
                        height: 180,
                        child: Image.asset(
                          'assets/images/grumblor/grumblor_idle.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Text('😌', style: TextStyle(fontSize: 60)),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥',
                              style: TextStyle(fontSize: 60)),
                          const SizedBox(height: 12),
                          const Text(
                            'CHECKPOINT REACHED',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              shadows: [
                                Shadow(
                                    color: Color(0xFFFFAA00), blurRadius: 16)
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Level ${widget.level} · Progress Saved',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 36),
                          GestureDetector(
                            onTap: widget.onRest,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A1200),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFFFAA00), width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x60FFAA00), blurRadius: 16)
                                ],
                              ),
                              child: const Text(
                                'REST',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ember {
  double x, y, vx, vy, size, life;
  _Ember(
      {required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.size,
      required this.life});
}

class _EmberPainter extends CustomPainter {
  final List<_Ember> embers;
  _EmberPainter(this.embers);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      final opacity = e.life.clamp(0.0, 1.0);
      final color =
          Color.lerp(Colors.red, const Color(0xFFFFD700), 1 - e.life)!
              .withOpacity(opacity);
      canvas.drawCircle(
          Offset(e.x * size.width, e.y * size.height), e.size, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => true;
}
