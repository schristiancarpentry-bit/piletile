import 'dart:math';
import 'dart:async' as async;
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'board.dart';
import 'tile.dart';
import 'special_tiles.dart';
import '../managers/round_manager.dart';
import '../managers/level_manager.dart';
import '../managers/timer_manager.dart';
import '../managers/audio_manager.dart';
import '../theme/tile_themes.dart';

enum GamePhase { dropping, countdown, matchWindow, roundComplete, levelComplete, suddenDeath }

class PileTileGame extends FlameGame with TapCallbacks {
  final int journeyId;
  final int level;
  final void Function(GamePhase phase, Map<String, dynamic> data) onPhaseChange;
  final void Function() onSuddenDeath;
  final void Function() onLevelComplete;

  PileTileGame({
    required this.journeyId,
    required this.level,
    required this.onPhaseChange,
    required this.onSuddenDeath,
    required this.onLevelComplete,
  });

  late Board _board;
  late RoundManager _roundManager;
  late TimerManager _timerManager;
  final AudioManager _audio = AudioManager();

  GamePhase _phase = GamePhase.dropping;
  int _currentRound = 0;
  int _wrongTaps = 0;
  double _shakeAmount = 0;
  bool _isShaking = false;
  double _countdownValue = 3;
  double _countdownTimer = 0;
  bool _countdownActive = false;

  static const double tileW = 80;
  static const double tileH = 44;
  static const double stackOffsetY = -6;
  static const int cols = 8;
  static const int rows = 5;

  int get pairCeiling => LevelManager.pairCeiling(level);

  @override
  Future<void> onLoad() async {
    _board = Board(columns: cols, rows: rows);
    _roundManager = RoundManager();
    _timerManager = TimerManager(
      onTick: (r) {
        onPhaseChange(GamePhase.matchWindow, {'timer': r, 'round': _currentRound, 'ceiling': pairCeiling});
      },
      onExpired: _onTimerExpired,
    );
    _startNextRound();
  }

  void _startNextRound() {
    _currentRound++;
    if (_currentRound > pairCeiling) {
      _phase = GamePhase.levelComplete;
      onLevelComplete();
      return;
    }
    _phase = GamePhase.dropping;
    onPhaseChange(GamePhase.dropping, {'round': _currentRound, 'ceiling': pairCeiling});
    _dropTiles();
  }

  async.Timer? _dropTimer;

  void _dropTiles() {
    final drops = _roundManager.generateRound(pairCount: _currentRound, board: _board, round: _currentRound);
    int idx = 0;

    void dropNext() {
      if (idx >= drops.length * 2) {
        _startCountdown();
        return;
      }
      final pairIdx = idx ~/ 2;
      final isSecond = idx % 2 == 1;
      final drop = drops[pairIdx];
      if (!isSecond) {
        _board.placeTile(drop.$1, drop.$2, drop.$3);
      } else {
        _board.placeTile(drop.$4, drop.$5, drop.$6);
      }
      _audio.playThud();
      _startShake(2);
      idx++;
      _dropTimer = async.Timer(const Duration(milliseconds: 250), dropNext);
    }

    dropNext();
  }

  void _startCountdown() {
    _countdownValue = 3;
    _countdownActive = true;
    _countdownTimer = 0;
    _phase = GamePhase.countdown;
    _audio.playCountdown();
    onPhaseChange(GamePhase.countdown, {'countdown': 3, 'round': _currentRound});
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isShaking) {
      _shakeAmount = (_shakeAmount - dt * 20).clamp(0, 8);
      if (_shakeAmount <= 0) _isShaking = false;
    }

    if (_countdownActive) {
      _countdownTimer += dt;
      if (_countdownTimer >= 1.0) {
        _countdownTimer = 0;
        _countdownValue--;
        if (_countdownValue <= 0) {
          _countdownActive = false;
          _openMatchWindow();
        } else {
          onPhaseChange(GamePhase.countdown, {'countdown': _countdownValue.toInt(), 'round': _currentRound});
        }
      }
    }
  }

  void _openMatchWindow() {
    _phase = GamePhase.matchWindow;
    final secs = LevelManager.matchWindowSeconds(_currentRound);
    _timerManager.start(secs);
    onPhaseChange(GamePhase.matchWindow, {'timer': secs, 'round': _currentRound, 'ceiling': pairCeiling});
  }

  void _onTimerExpired() {
    _phase = GamePhase.suddenDeath;
    _audio.playGameOver();
    onSuddenDeath();
  }

  void _startShake(double amount) {
    _shakeAmount = amount;
    _isShaking = true;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_phase != GamePhase.matchWindow) return;

    final pos = event.localPosition;
    final col = _colFromX(pos.x);
    final row = _rowFromY(pos.y);
    if (col < 0 || col >= cols || row < 0 || row >= rows) return;

    _board.trySelectOrMatch(col, row,
      onMatch: (a, b) {
        _audio.playCrack();
        _startShake(1.5);
        if (a.isSpecial && a.specialId != null) {
          SpecialTileHandler.applySpecial(a.specialId!, _board, (secs) {
            _timerManager.applySlowMo(secs);
          });
          _audio.playSpecial();
        }
        if (a.isBad && a.badId != null) {
          SpecialTileHandler.applyBad(a.badId!, _board,
            (delta) => _timerManager.adjustTime(delta),
            () {},
          );
          _audio.playBad();
        }
        if (_board.allMatched) {
          _timerManager.stop();
          _phase = GamePhase.roundComplete;
          onPhaseChange(GamePhase.roundComplete, {'round': _currentRound, 'ceiling': pairCeiling});
          _startNextRound();
        }
      },
      onWrongTap: (tile) {
        _wrongTaps++;
        _audio.playWrong();
        async.Timer(const Duration(milliseconds: 300), () {
          tile.isFlashingRed = false;
        });
      },
    );
  }

  int _colFromX(double x) {
    final boardLeft = (size.x - cols * tileW) / 2;
    return ((x - boardLeft) / tileW).floor();
  }

  int _rowFromY(double y) {
    final boardTop = (size.y - rows * (tileH + 8)) / 2 + 40;
    return ((y - boardTop) / (tileH + 8)).floor();
  }

  int get wrongTaps => _wrongTaps;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final shake = _isShaking ? (sin(DateTime.now().millisecondsSinceEpoch * 0.05) * _shakeAmount) : 0.0;
    canvas.save();
    canvas.translate(shake, shake * 0.5);
    _renderBoard(canvas);
    canvas.restore();
  }

  void _renderBoard(Canvas canvas) {
    final theme = kDefaultTheme;
    final boardLeft = (size.x - cols * tileW) / 2;
    final boardTop = (size.y - rows * (tileH + 8)) / 2 + 40;

    final bgPaint = Paint()..color = theme.backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), bgPaint);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = boardLeft + c * tileW;
        final y = boardTop + r * (tileH + 8);
        _renderStack(canvas, c, r, x, y, theme);
      }
    }
  }

  void _renderStack(Canvas canvas, int col, int row, double x, double y, TileTheme theme) {
    final stack = _board.stackAt(col, row);
    if (stack.isEmpty) {
      _renderSlot(canvas, x, y);
      return;
    }

    _renderSlot(canvas, x, y);

    final depth = stack.length;
    if (depth > 2 && stack.hiddenCount > 0) {
      final badgePaint = Paint()..color = Colors.white.withOpacity(0.25);
      canvas.drawCircle(Offset(x + tileW - 10, y + 10), 10, badgePaint);
      final tp = TextPainter(
        text: TextSpan(text: '${stack.hiddenCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + tileW - 10 - tp.width / 2, y + 10 - tp.height / 2));
    }

    if (depth >= 2) {
      final second = stack.second!;
      _renderTile(canvas, second, x, y + stackOffsetY * 1, greyed: true, selected: false, flashing: false);
    }

    final top = stack.top!;
    final isSelected = _board.selectedCol == col && _board.selectedRow == row;
    _renderTile(canvas, top, x, y + stackOffsetY * (depth > 1 ? 0 : 0),
      greyed: false, selected: isSelected, flashing: top.isFlashingRed);
  }

  void _renderSlot(Canvas canvas, double x, double y) {
    final slotPaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill;
    final slotBorder = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 2, tileW - 4, tileH - 4), const Radius.circular(6));
    canvas.drawRRect(rect, slotPaint);
    canvas.drawRRect(rect, slotBorder);
  }

  void _renderTile(Canvas canvas, Tile tile, double x, double y, {required bool greyed, required bool selected, required bool flashing}) {
    Color color = tile.baseColor;
    if (tile.isFrosted) color = const Color(0xFF8BB8D4);
    if (greyed) color = color.withOpacity(0.4);
    if (flashing) color = Colors.red;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 4, y + 4, tileW - 4, tileH - 4), const Radius.circular(8)), shadow);

    final paint = Paint()..color = color;
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 2, tileW - 4, tileH - 4), const Radius.circular(8));
    canvas.drawRRect(rect, paint);

    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(greyed ? 0.05 : 0.2), Colors.transparent],
      ).createShader(Rect.fromLTWH(x, y, tileW, tileH / 2));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 2, tileW - 4, tileH / 2 - 2), const Radius.circular(8)), gloss);

    if (selected) {
      final selPaint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rect, selPaint);
    }

    if (tile.isSpecial) {
      final glowPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rect, glowPaint);
    } else if (tile.isBad) {
      final glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rect, glowPaint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: tile.symbol,
        style: TextStyle(
          color: greyed ? Colors.white.withOpacity(0.3) : Colors.white,
          fontSize: tile.isSpecial || tile.isBad ? 18 : 16,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x + (tileW - tp.width) / 2, y + (tileH - tp.height) / 2));
  }

  @override
  void onRemove() {
    _dropTimer?.cancel();
    _timerManager.dispose();
    super.onRemove();
  }
}
