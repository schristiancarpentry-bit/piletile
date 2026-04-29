import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GameOverScreen extends StatelessWidget {
  final int diedOnRound;
  final int diedOnLevel;
  final int droppingToLevel;
  final int bonfireLevel;
  final VoidCallback onContinue;

  const GameOverScreen({
    super.key,
    required this.diedOnRound,
    required this.diedOnLevel,
    required this.droppingToLevel,
    required this.bonfireLevel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SUDDEN DEATH',
              style: TextStyle(
                color: Colors.red,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: [Shadow(color: Colors.red, blurRadius: 30), Shadow(color: Colors.red, blurRadius: 60)],
              ),
            ).animate().shakeX(duration: 600.ms, hz: 8, amount: 6),
            const SizedBox(height: 12),
            _CrackPainter(),
            const SizedBox(height: 32),
            _InfoRow(label: 'DIED ON', value: 'Level $diedOnLevel · Round $diedOnRound'),
            const SizedBox(height: 8),
            _InfoRow(label: 'DROPPING TO', value: 'Level $droppingToLevel', valueColor: Colors.red),
            const SizedBox(height: 8),
            _InfoRow(label: 'BONFIRE AT', value: 'Level $bonfireLevel', valueColor: Colors.orange),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onContinue,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 1.5),
                ),
                child: const Text('CONTINUE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrackPainter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(300, 40),
      painter: _CrackLinePainter(),
    );
  }
}

class _CrackLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width * 0.3, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(size.width * 0.7, size.height * 0.1);
    path.lineTo(size.width, size.height / 2);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, paint..color = Colors.red.withOpacity(0.2)..strokeWidth = 8);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label  ', style: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 2)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}
