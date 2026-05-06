import 'dart:math';
import 'dart:async' as async;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'board.dart';
import 'tile.dart';
import 'special_tiles.dart';
import '../managers/round_manager.dart';
import '../managers/level_manager.dart';
import '../managers/timer_manager.dart';
import '../managers/audio_manager.dart';
import '../managers/progress_manager.dart';
import '../managers/analytics_manager.dart';
import '../config/journey_config.dart';

enum GamePhase {
  dropping, countdown, matchWindow, roundComplete, levelComplete, suddenDeath, revivePrompt
}

const List<List<int>> _kPyramidCols = [
  [2],
  [1, 2, 3],
  [0, 1, 2, 3, 4],
  [0, 1, 2, 3, 4],
];
const int _kPyramidRows = 4;
const int _kPyramidMaxCols = 5;

// ─── Data classes ──────────────────────────────────────────────────────────

class _DroppingTile {
  final Tile tile;
  final int col, row;
  final double targetX, targetY;
  final double startX, startY;
  double progress = 0.0; // 0.0 → 1.0: rises from pile to board position

  _DroppingTile({
    required this.tile, required this.col, required this.row,
    required this.targetX, required this.targetY,
    required this.startX, required this.startY,
  });

  double get scale => 0.3 + progress * 0.7;
}

// Cosmetic tile sitting in the pile (non-interactive)
class _PileDisplayTile {
  final Tile tile;
  double x, y;
  double rotDeg;
  double opacity;

  _PileDisplayTile({
    required this.tile, required this.x, required this.y,
    required this.rotDeg, this.opacity = 1.0,
  });
}

// Matched tile dissolving upward as golden restoration dust
class _DissolvingTile {
  final Tile tile;
  double x, y;
  double scale;
  double life; // 1.0 → 0.0
  double vy;
  double rotation;
  double spinVelocity;
  bool isStarSpin;

  _DissolvingTile({
    required this.tile, required this.x, required this.y,
    this.scale = 1.0, this.life = 1.0, this.vy = -110,
    this.rotation = 0.0, this.spinVelocity = 0.0, this.isStarSpin = false,
  });
}

// Skull tile that rushes toward the viewer on match — zooms in and fades
class _SkullRush {
  double x, y;
  double scale; // grows from 1.0 toward ~4.0
  double life;  // 1.0 → 0.0

  _SkullRush({required this.x, required this.y})
      : scale = 1.0,
        life = 1.0;
}

class _ScorePop {
  double x, y, life;
  _ScorePop({required this.x, required this.y, this.life = 1.0});
}

class _Particle {
  double x, y, vx, vy, life, size;
  final Color color;
  _Particle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.life, required this.size, required this.color,
  });
}

class _ShockRing {
  final double cx, cy, baseW, baseH;
  final Color color;
  double radius = 0, life = 1.0;
  _ShockRing({required this.cx, required this.cy,
      required this.baseW, required this.baseH,
      this.color = const Color(0xFFD49040)});
}

class _ScreenFlash {
  Color color;
  double life;
  _ScreenFlash(this.color, this.life);
}

class _FloatingText {
  final String text;
  final Color color;
  double x, y, life;
  double vy;
  _FloatingText({required this.text, required this.color,
      required this.x, required this.y, this.life = 1.0, this.vy = -40});
}

class _StarParticle {
  double x, y, vx, vy, life, size, rotation, spinVelocity, hue;
  _StarParticle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.life, required this.size, required this.hue,
    this.rotation = 0.0, this.spinVelocity = 0.0,
  });
}

// ─── Game ──────────────────────────────────────────────────────────────────

class PileTileGame extends FlameGame with TapCallbacks {
  final int journeyId;
  final int level;
  final int startRound;
  final double topInset;
  final double bottomInset;
  final void Function(GamePhase phase, Map<String, dynamic> data) onPhaseChange;
  final void Function(int round) onSuddenDeath;
  final void Function(int wrongTaps) onLevelComplete;
  final VoidCallback? onWrongTap;
  final void Function(String expression, int durationMs)? onGrumlorEvent;
  final void Function(String event)? onGameEvent;
  final VoidCallback? onReviveOffer;

  PileTileGame({
    required this.journeyId,
    required this.level,
    this.startRound = 1,
    required this.topInset,
    this.bottomInset = 0.0,
    required this.onPhaseChange,
    required this.onSuddenDeath,
    required this.onLevelComplete,
    this.onWrongTap,
    this.onGrumlorEvent,
    this.onGameEvent,
    this.onReviveOffer,
  });

  late Board _board;
  late RoundManager _roundManager;
  late TimerManager _timerManager;
  final AudioManager _audio = AudioManager();
  final ProgressManager _progress = ProgressManager();
  final AnalyticsManager _analytics = AnalyticsManager();

  // Sprite sheet
  ui.Image? _tileSheet;
  bool _useSheet = false;
  double _tileAspect = 0.75;
  final List<ui.Image?> _tileImages = List.filled(10, null);

  // Special tile images
  ui.Image? _imgHourglass, _imgStar, _imgSkullTile, _imgChaos;

  // Pile image
  ui.Image? _imgPile;

  // Journey tile colours (fallback)
  Color _tileBase  = const Color(0xFFC8952A);
  Color _tileLight = const Color(0xFFE8C050);
  Color _tileDark  = const Color(0xFF8A6018);
  Color _tileDeep  = const Color(0xFF4A3010);
  Color _symLine   = const Color(0xFF3A2808);
  Color _symFill   = const Color(0xFF5A3C10);

  // Phase & round state
  GamePhase _phase = GamePhase.dropping;
  int _currentRound = 0;
  int _wrongTaps = 0;
  double _shakeAmount = 0;
  bool _isShaking = false;
  double _countdownValue = 3;
  double _countdownTimer = 0;
  bool _countdownActive = false;

  // Layout
  double tileW = 60;
  double tileH = 80;
  double tileGap = 5;
  double stackLayerOffset = 10;
  double _boardLeft = 0;
  double _boardTop = 0;
  double _boardW = 0;
  double _boardH = 0;
  // Living Pile zone (bottom 28% of canvas)
  double _pileZoneTop = 0;
  double _pileZoneH = 0;

  // Drop animation (tiles rise from pile)
  final List<_DroppingTile> _droppingTiles = [];
  List<(Tile, int, int, Tile, int, int)> _dropQueue = [];
  int _pairLandCount = 0;
  int _totalPendingLands = 0;

  // Living Pile
  final List<_PileDisplayTile> _pileDisplayTiles = [];
  final List<_DissolvingTile> _dissolvingTiles = [];
  double _pileShakeAmt = 0.0;
  int _restoredCount = 0;
  int _badPileCount = 0;
  int _skullPairIdCounter = 200;

  // Skull rush (zoom toward viewer on match)
  final List<_SkullRush> _skullRushes = [];

  // Score pops
  final List<_ScorePop> _scorePops = [];

  // Particles (shared, capped at 30)
  final List<_Particle> _particles = [];
  final List<_StarParticle> _starParticles = [];
  final List<_ShockRing> _rings = [];
  final List<_ScreenFlash> _flashes = [];
  final List<_FloatingText> _floatingTexts = [];

  // Revive stone state
  bool _reviveUsedThisRound = false;
  bool _reviveAcceptedThisRound = false;

  // Special state
  bool _shuffleLocked = false;
  bool _shuffleSpinning = false;
  double _shuffleSpinElapsed = 0.0;
  double _shuffleSpinAngle = 0.0;
  static const _kShuffleDuration = 2.0; // seconds

  // Timers
  async.Timer? _hazardTimer;
  final List<async.Timer> _timers = [];

  final Random _rng = Random();

  int get pairCeiling => LevelManager.pairCeiling(level);

  @override
  Color backgroundColor() => Colors.transparent;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    final cfg = journeyConfig(journeyId);
    final p = cfg.primaryColour;
    _tileBase  = p;
    _tileLight = _mixColor(p, const Color(0xFFFFFFFF), 0.38);
    _tileDark  = _mixColor(p, const Color(0xFF000000), 0.38);
    _tileDeep  = _mixColor(p, const Color(0xFF000000), 0.62);
    _symLine   = _mixColor(p, const Color(0xFF000000), 0.56);
    _symFill   = _mixColor(p, const Color(0xFF000000), 0.40);

    // Load tile images
    final sheet = await _loadImage(cfg.tileSheetAsset);
    if (sheet != null) {
      _tileSheet = sheet;
      _useSheet = true;
      _tileAspect = (sheet.width / 5.0) / (sheet.height / 2.0);
    } else {
      for (int i = 0; i < 10; i++) {
        _tileImages[i] = await _loadImage('assets/images/tiles/tile_$i.png');
      }
      final first = _tileImages.firstWhere((img) => img != null, orElse: () => null);
      if (first != null) _tileAspect = first.width / first.height.toDouble();
    }

    // Load special tile images
    _imgHourglass = await _loadImage('assets/images/tiles/tile_special_hourglass.png');
    _imgStar      = await _loadImage('assets/images/tiles/tile_special_star.png');
    _imgSkullTile = await _loadImage('assets/images/tiles/tile_special_skull.png');
    _imgChaos     = await _loadImage('assets/images/tiles/tile_special_chaos.png');
    _imgPile      = await _loadImage('assets/images/pile_bedrock.png');

    _computeLayout();
    _initLivingPile();

    _board = Board(columns: _kPyramidMaxCols, rows: _kPyramidRows);
    final valid = <(int, int)>[];
    for (int r = 0; r < _kPyramidCols.length; r++) {
      for (final c in _kPyramidCols[r]) valid.add((c, r));
    }
    _board.setValidPositions(valid);

    _roundManager = RoundManager();
    _timerManager = TimerManager(
      onTick: (r) => onPhaseChange(GamePhase.matchWindow,
          {'timer': r, 'round': _currentRound, 'ceiling': pairCeiling,
           'slowmo': _timerManager.isSlowMoActive}),
      onExpired: _onTimerExpired,
    );
    // Skip to the bonfire round on retries — first attempt always starts at 1
    _currentRound = (startRound - 1).clamp(0, pairCeiling - 1);
    _startNextRound();
  }

  void _computeLayout() {
    // Portrait layout: HUD (Flutter overlay 80px top) + arena + Living Pile (bottom 28%)
    const double zoneAH = 80.0;
    const double padH   = 12.0;
    tileGap = 5;

    _pileZoneH   = size.y * 0.28;
    _pileZoneTop = size.y - _pileZoneH;

    final double arenaTop    = topInset + zoneAH;
    final double arenaBottom = _pileZoneTop;
    final double arenaH      = arenaBottom - arenaTop;

    const double targetAspect = 0.75;
    final double availW   = size.x - padH * 2;
    final double maxTileW = (availW - tileGap * (_kPyramidMaxCols - 1)) / _kPyramidMaxCols;
    final double maxTileH = (arenaH - tileGap * (_kPyramidRows - 1)) / _kPyramidRows;
    double tw = min(maxTileW, 88.0);
    double th = tw / targetAspect;
    if (th > maxTileH) { th = maxTileH; tw = th * targetAspect; }
    tileW = tw.clamp(36.0, 88.0);
    tileH = tileW / targetAspect;
    stackLayerOffset = (tileW * 0.15).clamp(5.0, 12.0);

    _boardW = _kPyramidMaxCols * tileW + (_kPyramidMaxCols - 1) * tileGap;
    _boardH = _kPyramidRows * tileH + (_kPyramidRows - 1) * tileGap;
    _boardLeft = (size.x - _boardW) / 2;
    _boardTop  = arenaTop + (arenaH - _boardH) / 2;
  }

  Future<ui.Image?> _loadImage(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  // ─── Game flow ─────────────────────────────────────────────────────────

  void _startNextRound() {
    _reviveUsedThisRound = false;
    _reviveAcceptedThisRound = false;
    _currentRound++;
    if (_currentRound > pairCeiling) {
      _phase = GamePhase.levelComplete;
      onLevelComplete(_wrongTaps);
      return;
    }
    _phase = GamePhase.dropping;
    onPhaseChange(GamePhase.dropping,
        {'round': _currentRound, 'ceiling': pairCeiling});
    _dropTiles();
  }

  void _dropTiles() {
    final drops = _roundManager.generateRound(
        pairCount: _currentRound, board: _board, round: _currentRound, level: level);
    _totalPendingLands = drops.length * 2;
    _dropQueue = List.from(drops);
    _dropNextPair();
  }

  void _dropNextPair() {
    if (_dropQueue.isEmpty) return;
    final pair = _dropQueue.removeAt(0);
    _pairLandCount = 2;
    _launchDrop(pair.$1, pair.$2, pair.$3);
    _after(100, () => _launchDrop(pair.$4, pair.$5, pair.$6));
  }

  void _launchDrop(Tile tile, int col, int row) {
    final tx = _boardLeft + col * (tileW + tileGap);
    final ty = _boardTop + row * (tileH + tileGap);
    // Start near the top of the pile image — spread horizontally, clustered vertically
    final sx = size.x * 0.15 + _rng.nextDouble() * size.x * 0.70;
    final sy = _pileZoneTop + _pileZoneH * 0.15 + _rng.nextDouble() * _pileZoneH * 0.25;
    _droppingTiles.add(_DroppingTile(
        tile: tile, col: col, row: row,
        targetX: tx, targetY: ty,
        startX: sx, startY: sy));
  }

  void _onTileLanded(_DroppingTile dt) {
    _board.placeTile(dt.tile, dt.col, dt.row);
    _spawnImpact(dt.targetX + tileW / 2, dt.targetY + tileH / 2,
        color: const Color(0xFFD49040));
    _startShake(4.0);

    _totalPendingLands--;
    _pairLandCount--;

    if (_pairLandCount <= 0) {
      if (_dropQueue.isNotEmpty) {
        _after(700, _dropNextPair);
      } else if (_totalPendingLands <= 0) {
        _after(450, _startCountdown);
      }
    }
  }

  void _startCountdown() {
    _countdownValue = 3;
    _countdownActive = true;
    _countdownTimer = 0;
    _phase = GamePhase.countdown;
    _audio.playCountdown();
    onPhaseChange(GamePhase.countdown,
        {'countdown': 3, 'round': _currentRound});
  }

  void _openMatchWindow() {
    _phase = GamePhase.matchWindow;
    final secs = LevelManager.matchWindowSeconds(_currentRound, level: level);
    _timerManager.start(secs);
    onPhaseChange(GamePhase.matchWindow,
        {'timer': secs, 'round': _currentRound, 'ceiling': pairCeiling,
         'slowmo': false});
    _startHazard();
  }

  void _onTimerExpired() {
    _hazardTimer?.cancel();

    if (_reviveAcceptedThisRound) {
      _analytics.reviveFail(journeyId, level, _currentRound);
      _phase = GamePhase.suddenDeath;
      _audio.playGameOver();
      onGrumlorEvent?.call('flinch', 1500);
      onSuddenDeath(_currentRound);
      return;
    }

    if (!_reviveUsedThisRound && _board.tileCount ~/ 2 <= 3 &&
        _progress.hasReviveStone) {
      _reviveUsedThisRound = true;
      _phase = GamePhase.revivePrompt;
      _analytics.reviveOffered(journeyId, level, _currentRound);
      onGrumlorEvent?.call('reluctant', 4000);
      onReviveOffer?.call();
      return;
    }

    _phase = GamePhase.suddenDeath;
    _audio.playGameOver();
    onGrumlorEvent?.call('flinch', 1500);
    onSuddenDeath(_currentRound);
  }

  void acceptRevive() {
    if (_phase != GamePhase.revivePrompt) return;
    _progress.spendReviveStone();
    _analytics.reviveAccepted(journeyId, level, _currentRound);
    _reviveAcceptedThisRound = true;
    onGrumlorEvent?.call('throw', 1200);
    _phase = GamePhase.matchWindow;
    final secs = LevelManager.matchWindowSeconds(_currentRound, level: level);
    _timerManager.start(secs);
    onPhaseChange(GamePhase.matchWindow, {
      'timer': secs, 'round': _currentRound, 'ceiling': pairCeiling, 'slowmo': false,
    });
    _startHazard();
  }

  void declineRevive({bool timeout = false}) {
    if (_phase != GamePhase.revivePrompt) return;
    _analytics.reviveDeclined(journeyId, level, _currentRound, timeout: timeout);
    onGrumlorEvent?.call('shrug', 1200);
    _phase = GamePhase.suddenDeath;
    _audio.playGameOver();
    onSuddenDeath(_currentRound);
  }

  // ─── Match handling ─────────────────────────────────────────────────────

  void _onMatchAt(Tile a, int ac, int ar, Tile b, int bc, int br) {
    _audio.playCrack();
    _startShake(1.5);

    final ax = _boardLeft + ac * (tileW + tileGap) + tileW / 2;
    final ay = _boardTop + ar * (tileH + tileGap) + tileH / 2;
    final bx = _boardLeft + bc * (tileW + tileGap) + tileW / 2;
    final by = _boardTop + br * (tileH + tileGap) + tileH / 2;
    final midX = (ax + bx) / 2;
    final midY = (ay + by) / 2;

    // Special tile effects (hourglass, star, chaos)
    if (a.isSpecial && a.specialId != null) {
      _triggerSpecial(a.specialId!, midX, midY);
    }

    // Bad tile effects (skull, scramble)
    if (a.isBad && a.badId != null) {
      _triggerBad(a.badId!, midX, midY);
    }

    // Bad tiles crumble — pile shakes harder
    if (a.isBad) {
      if (a.badId == BadTileId.skull) {
        _skullRushes.add(_SkullRush(x: ax, y: ay));
        _skullRushes.add(_SkullRush(x: bx, y: by));
        _audio.playSkullLaugh();
      }
      _spawnCrumble(ax, ay);
      _spawnCrumble(bx, by);
      _flashes.add(_ScreenFlash(const Color(0xFFFF0000), 0.35));
      _badPileCount++;
      _pileShakeAmt = (_pileShakeAmt + 10.0).clamp(0, 20);
    } else {
      // Tiles dissolve upward — restored to the Great Pile
      _launchDissolve(a, ax, ay);
      _launchDissolve(b, bx, by);
    }

    // Score pop
    _scorePops.add(_ScorePop(x: midX, y: midY - 10));

    // Only fire round-complete once (guard against double-scheduling from _autoMatch5Pairs)
    if (_board.allMatched && _phase == GamePhase.matchWindow) {
      _hazardTimer?.cancel();
      _timerManager.stop();
      _phase = GamePhase.roundComplete;
      if (_reviveAcceptedThisRound) {
        _analytics.reviveSuccess(journeyId, level, _currentRound);
      }
      onPhaseChange(GamePhase.roundComplete,
          {'round': _currentRound, 'ceiling': pairCeiling});
      _after(420, _startNextRound);
    }
  }

  void _launchDissolve(Tile tile, double cx, double cy) {
    final isWildcard = tile.isSpecial && tile.specialId == SpecialTileId.wildcard;
    final spinDir = _rng.nextBool() ? 1.0 : -1.0;
    _dissolvingTiles.add(_DissolvingTile(
      tile: tile, x: cx, y: cy,
      vy: -80 - _rng.nextDouble() * 60,
      isStarSpin: isWildcard,
      spinVelocity: isWildcard ? spinDir * (5.0 + _rng.nextDouble() * 4.0) : 0.0,
    ));
    if (isWildcard) {
      _spawnRainbowStarBurst(cx, cy);
    } else {
      _spawnGoldBurst(cx, cy);
    }
    _restoredCount++;
    // Add a pile display tile at a random spot in the pile
    _addToPile(tile);
  }

  void _addToPile(Tile tile) {
    final px = 8 + _rng.nextDouble() * (size.x - 16);
    final py = _pileZoneTop + 8 + _rng.nextDouble() * (_pileZoneH - 20);
    final rot = (_rng.nextDouble() - 0.5) * 40;
    _pileDisplayTiles.add(_PileDisplayTile(
      tile: tile, x: px, y: py, rotDeg: rot, opacity: 0.0,
    ));
    // Keep pile from getting too crowded
    if (_pileDisplayTiles.length > 60) _pileDisplayTiles.removeAt(0);
  }

  void _initLivingPile() {
    _pileDisplayTiles.clear();
    // Seed with a handful of background stone slabs for visual texture
    for (int i = 0; i < 18; i++) {
      final t = Tile(colorIndex: _rng.nextInt(10), pairId: -1);
      final px = 8 + _rng.nextDouble() * (size.x - 16);
      final py = _pileZoneTop + 8 + _rng.nextDouble() * (_pileZoneH - 20);
      final rot = (_rng.nextDouble() - 0.5) * 45;
      _pileDisplayTiles.add(_PileDisplayTile(
        tile: t, x: px, y: py, rotDeg: rot,
        opacity: 0.4 + _rng.nextDouble() * 0.5,
      ));
    }
  }

  // ─── Special effects ─────────────────────────────────────────────────────

  void _triggerSpecial(SpecialTileId id, double cx, double cy) {
    switch (id) {
      case SpecialTileId.slowMo:
        _timerManager.applySlowMo(2.0);
        _audio.playSlowMoSound();
        // Teal ripple rings
        for (int i = 0; i < 3; i++) {
          _after(i * 120, () {
            _rings.add(_ShockRing(
                cx: cx, cy: cy,
                baseW: size.x * 0.5, baseH: size.y * 0.5,
                color: const Color(0xFF00CCFF)));
          });
        }
        _flashes.add(_ScreenFlash(const Color(0xFF004466), 0.3));
        onGameEvent?.call('slowmo_start');

      case SpecialTileId.wildcard:
        _audio.playWildcardSound();
        _autoMatch5Pairs();
        // Gold burst
        _spawnGoldBurst(cx, cy);
        _flashes.add(_ScreenFlash(const Color(0xFFFFD700), 0.2));
        _floatingTexts.add(_FloatingText(
            text: '✨ AUTO-MATCH', color: const Color(0xFFFFD700),
            x: size.x / 2 - 50, y: size.y / 2 - 20, vy: -30));
        onGrumlorEvent?.call('celebrate', 800);

      case SpecialTileId.shuffle:
        if (_shuffleLocked) return;
        _audio.playChaosSound();
        _doShuffle(cx, cy);
    }
  }

  void _triggerBad(BadTileId id, double cx, double cy) {
    _audio.playBad();
    switch (id) {
      case BadTileId.skull:
        _timerManager.adjustTime(-2.0);
        // Skull slam text
        _floatingTexts.add(_FloatingText(
            text: '💀 -2s', color: const Color(0xFFFF2222),
            x: cx - 20, y: cy - 20, vy: -50, life: 0.8));
        // Timer shake
        _startShake(8.0);
        _after(300, () => _startShake(8.0));
        // Grumblor rage
        onGrumlorEvent?.call('rage', 1000);

      case BadTileId.scramble:
        if (_shuffleLocked) return;
        _audio.playChaosSound();
        // Dark flash + vortex rings
        _flashes.add(_ScreenFlash(const Color(0xFF220044), 0.4));
        for (int i = 0; i < 4; i++) {
          _after(i * 80, () {
            _rings.add(_ShockRing(
                cx: size.x / 2, cy: size.y / 2,
                baseW: size.x * 0.3 + i * 30,
                baseH: size.y * 0.3 + i * 20,
                color: const Color(0xFF330066)));
          });
        }
        _floatingTexts.add(_FloatingText(
            text: '🌀 SCRAMBLED!', color: const Color(0xFFAA44FF),
            x: size.x / 2 - 55, y: size.y / 2 - 20, vy: -30, life: 0.9));
        onGrumlorEvent?.call('fuming', 1500);
        _doShuffle(cx, cy);
    }
  }

  void _doShuffle(double cx, double cy) {
    _shuffleLocked = true;
    _timerManager.pause();
    onGameEvent?.call('shuffle_start');
    _startShake(6.0);

    // Start spin
    _shuffleSpinning = true;
    _shuffleSpinElapsed = 0.0;
    _shuffleSpinAngle = 0.0;

    // Actually reshuffle board at the 180° midpoint so the swap is hidden mid-spin
    _after(1000, () {
      SpecialTileHandler.applySpecial(SpecialTileId.shuffle, _board, (_) {});
      _spawnGoldBurst(cx, cy);
      onGrumlorEvent?.call('shocked', 1000);
    });
    // update() drives the remaining 1s of spin and handles cleanup
  }

  void _autoMatch5Pairs() {
    final byKey = <String, List<(int, int, Tile)>>{};
    for (final pos in _board.allPositions) {
      final t = _board.stackAt(pos.$1, pos.$2).top;
      if (t == null || t.isMatched || t.isSpecial || t.isBad) continue;
      final key = '${t.pairId}_${t.colorIndex}';
      byKey.putIfAbsent(key, () => []).add((pos.$1, pos.$2, t));
    }

    int matched = 0;
    for (final group in byKey.values) {
      if (matched >= 5 || group.length < 2) continue;
      final a = group[0];
      final b = group[1];
      _board.stackAt(a.$1, a.$2).pop();
      _board.stackAt(b.$1, b.$2).pop();
      a.$3.isMatched = true;
      b.$3.isMatched = true;

      final ax = _boardLeft + a.$1 * (tileW + tileGap) + tileW / 2;
      final ay = _boardTop + a.$2 * (tileH + tileGap) + tileH / 2;
      final bx = _boardLeft + b.$1 * (tileW + tileGap) + tileW / 2;
      final by = _boardTop + b.$2 * (tileH + tileGap) + tileH / 2;

      _launchDissolve(a.$3, ax, ay);
      _launchDissolve(b.$3, bx, by);
      matched++;
    }

    if (_board.allMatched && _phase == GamePhase.matchWindow) {
      _hazardTimer?.cancel();
      _timerManager.stop();
      _phase = GamePhase.roundComplete;
      onPhaseChange(GamePhase.roundComplete,
          {'round': _currentRound, 'ceiling': pairCeiling});
      _after(420, _startNextRound);
    }
  }

  void _addSkullTilePairs() {
    final positions = _board.allPositions;
    positions.shuffle(_rng);
    final count = min(3, positions.length);
    final pairId = _skullPairIdCounter++;
    int placed = 0;
    for (int i = 0; i < positions.length && placed < count * 2; i++) {
      final t = Tile(
        colorIndex: 9,
        pairId: placed < count ? pairId : pairId,
        type: TileType.bad,
        badId: BadTileId.skull,
      );
      _board.placeTile(t, positions[i].$1, positions[i].$2);
      final tx = _boardLeft + positions[i].$1 * (tileW + tileGap);
      final ty = _boardTop + positions[i].$2 * (tileH + tileGap);
      _droppingTiles.add(_DroppingTile(
          tile: t, col: positions[i].$1, row: positions[i].$2,
          targetX: tx, targetY: ty,
          startX: size.x * 0.15 + _rng.nextDouble() * size.x * 0.70,
          startY: _pileZoneTop + _pileZoneH * 0.15 + _rng.nextDouble() * _pileZoneH * 0.25));
      placed++;
    }
  }

  // ─── Hazards ─────────────────────────────────────────────────────────────

  void _startHazard() {
    final cfg = journeyConfig(journeyId);
    if (cfg.hazard == JourneyHazard.none) return;
    _hazardTimer?.cancel();
    _hazardTimer = async.Timer(const Duration(seconds: 3), _hazardTick);
  }

  void _hazardTick() {
    if (_phase != GamePhase.matchWindow) return;
    final cfg = journeyConfig(journeyId);
    if (cfg.hazard == JourneyHazard.freeze) _doFreeze();
    _hazardTimer = async.Timer(const Duration(seconds: 3), _hazardTick);
  }

  void _doFreeze() {
    final tops = <(int, int)>[];
    for (int r = 0; r < _kPyramidCols.length; r++) {
      for (final c in _kPyramidCols[r]) {
        final stack = _board.stackAt(c, r);
        if (stack.top != null && !stack.top!.isFrosted) tops.add((c, r));
      }
    }
    if (tops.isEmpty) return;
    tops.shuffle(_rng);
    final count = level >= 5 ? 3 : (1 + _rng.nextInt(2));
    for (int i = 0; i < count && i < tops.length; i++) {
      final tile = _board.stackAt(tops[i].$1, tops[i].$2).top;
      if (tile == null) continue;
      tile.isFrosted = true;
      _audio.playFreeze();
      _after(3000, () => tile.isFrosted = false);
    }
  }

  // ─── Particles ────────────────────────────────────────────────────────────

  void _spawnImpact(double cx, double cy, {required Color color}) {
    _rings.add(_ShockRing(cx: cx, cy: cy,
        baseW: tileW, baseH: tileH, color: color));
    _after(90, () => _rings.add(_ShockRing(
        cx: cx, cy: cy,
        baseW: tileW * 0.55, baseH: tileH * 0.55, color: color)));

    const dustColors = [
      Color(0xFF4A3820), Color(0xFF5A4828), Color(0xFF3D2A10),
      Color(0xFF6A5840), Color(0xFF888070), Color(0xFFBBA870),
    ];
    for (int i = 0; i < 18 && _particles.length < 30; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 90 + _rng.nextDouble() * 280;
      _particles.add(_Particle(
        x: cx, y: cy,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        life: 0.55 + _rng.nextDouble() * 0.45,
        size: 2.5 + _rng.nextDouble() * 5.0,
        color: dustColors[_rng.nextInt(dustColors.length)],
      ));
    }
  }


  void _spawnCrumble(double cx, double cy) {
    for (int i = 0; i < 12 && _particles.length < 30; i++) {
      final angle = pi * 0.5 + (_rng.nextDouble() - 0.5) * pi;
      final speed = 60 + _rng.nextDouble() * 120;
      _particles.add(_Particle(
        x: cx, y: cy,
        vx: cos(angle) * speed * 0.4, vy: abs(sin(angle) * speed),
        life: 0.4 + _rng.nextDouble() * 0.4,
        size: 2.0 + _rng.nextDouble() * 4.0,
        color: Color.lerp(const Color(0xFF880000),
            const Color(0xFF444444), _rng.nextDouble())!,
      ));
    }
  }

  void _spawnGoldBurst(double cx, double cy) {
    for (int i = 0; i < 20 && _particles.length < 30; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 120 + _rng.nextDouble() * 200;
      _particles.add(_Particle(
        x: cx, y: cy,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        life: 0.6 + _rng.nextDouble() * 0.4,
        size: 2.0 + _rng.nextDouble() * 4.0,
        color: Color.lerp(const Color(0xFFFFD700),
            const Color(0xFFFFFFFF), _rng.nextDouble())!,
      ));
    }
  }

  void _spawnRainbowStarBurst(double cx, double cy) {
    for (int i = 0; i < 18; i++) {
      final hue = (i / 18) * 360.0;
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 90 + _rng.nextDouble() * 190;
      _starParticles.add(_StarParticle(
        x: cx, y: cy,
        vx: cos(angle) * speed, vy: sin(angle) * speed,
        life: 0.7 + _rng.nextDouble() * 0.5,
        size: 5 + _rng.nextDouble() * 8,
        hue: hue,
        rotation: _rng.nextDouble() * 2 * pi,
        spinVelocity: (_rng.nextDouble() - 0.5) * 14,
      ));
    }
  }

  void _spawnPileAmbient(JourneyHazard hazard) {
    if (_particles.length >= 28) return;
    final cx = _rng.nextDouble() * size.x;
    final cy = _pileZoneTop + _rng.nextDouble() * _pileZoneH;
    Color color;
    switch (hazard) {
      case JourneyHazard.freeze:
        color = Color.lerp(const Color(0xFF88CCFF), const Color(0xFFCCEEFF),
            _rng.nextDouble())!;
      case JourneyHazard.sink:
        color = Color.lerp(const Color(0xFFFF6600), const Color(0xFFFFAA00),
            _rng.nextDouble())!;
      case JourneyHazard.none:
        color = Color.lerp(const Color(0xFF8A7040), const Color(0xFF5A4020),
            _rng.nextDouble())!;
    }
    _particles.add(_Particle(
      x: cx, y: cy,
      vx: (_rng.nextDouble() - 0.5) * 12,
      vy: -12 - _rng.nextDouble() * 22,
      life: 0.6 + _rng.nextDouble() * 0.8,
      size: 1.2 + _rng.nextDouble() * 2.5,
      color: color,
    ));
  }

  void _startShake(double amount) {
    _shakeAmount = (_shakeAmount + amount).clamp(0, 14);
    _isShaking = true;
  }

  void _after(int ms, void Function() fn) {
    _timers.add(async.Timer(Duration(milliseconds: ms), fn));
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    if (_isShaking) {
      _shakeAmount = (_shakeAmount - dt * 26).clamp(0, 14);
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
          onPhaseChange(GamePhase.countdown,
              {'countdown': _countdownValue.toInt(), 'round': _currentRound});
        }
      }
    }

    // Chaos shuffle spin animation
    if (_shuffleSpinning) {
      _shuffleSpinElapsed += dt;
      final t = (_shuffleSpinElapsed / _kShuffleDuration).clamp(0.0, 1.0);
      _shuffleSpinAngle = t * 2 * pi;
      if (_shuffleSpinElapsed >= _kShuffleDuration) {
        _shuffleSpinning = false;
        _shuffleSpinAngle = 0.0;
        _shuffleLocked = false;
        _timerManager.resume();
        onGameEvent?.call('shuffle_end');
      }
    }

    // Drop animation (tiles rise from pile to board)
    for (int i = _droppingTiles.length - 1; i >= 0; i--) {
      final dt_tile = _droppingTiles[i];
      dt_tile.progress += dt * 2.8;
      if (dt_tile.progress >= 1.0) {
        dt_tile.progress = 1.0;
        final landed = _droppingTiles.removeAt(i);
        _onTileLanded(landed);
      }
    }

    // Dissolve animation (matched tiles float up with golden glow)
    for (int i = _dissolvingTiles.length - 1; i >= 0; i--) {
      final dis = _dissolvingTiles[i];
      dis.y += dis.vy * dt;
      dis.vy *= (1 - dt * 2.0); // slow as they rise
      dis.life -= dt * 1.6;
      dis.scale = 1.0 + (1.0 - dis.life) * 0.4; // gentle expand as fades
      if (dis.isStarSpin) {
        dis.rotation += dis.spinVelocity * dt;
        dis.spinVelocity *= (1 - dt * 1.2);
        if (_starParticles.length < 60 && _rng.nextDouble() < dt * 20) {
          final hue = _rng.nextDouble() * 360;
          final angle = _rng.nextDouble() * 2 * pi;
          final speed = 55 + _rng.nextDouble() * 110;
          _starParticles.add(_StarParticle(
            x: dis.x, y: dis.y,
            vx: cos(angle) * speed, vy: sin(angle) * speed - 20,
            life: 0.5 + _rng.nextDouble() * 0.5,
            size: 4 + _rng.nextDouble() * 6,
            hue: hue,
            rotation: _rng.nextDouble() * 2 * pi,
            spinVelocity: (_rng.nextDouble() - 0.5) * 12,
          ));
        }
      }
      if (dis.life <= 0) _dissolvingTiles.removeAt(i);
    }

    // Fade in new pile display tiles
    for (final pt in _pileDisplayTiles) {
      if (pt.opacity < 0.85) pt.opacity = (pt.opacity + dt * 3.0).clamp(0.0, 0.85);
    }

    // Pile shake decay
    if (_pileShakeAmt > 0) _pileShakeAmt = (_pileShakeAmt - dt * 18.0).clamp(0, 20);

    // Particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.vx *= 1 - dt * 3.8;
      p.vy *= 1 - dt * 3.8;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt * 2.4;
      if (p.life <= 0) _particles.removeAt(i);
    }

    // Star particles
    for (int i = _starParticles.length - 1; i >= 0; i--) {
      final p = _starParticles[i];
      p.vx *= 1 - dt * 3.0;
      p.vy *= 1 - dt * 3.0;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rotation += p.spinVelocity * dt;
      p.life -= dt * 2.0;
      if (p.life <= 0) _starParticles.removeAt(i);
    }

    // Shock rings
    for (int i = _rings.length - 1; i >= 0; i--) {
      _rings[i].radius += 300 * dt;
      _rings[i].life -= dt * 4.0;
      if (_rings[i].life <= 0) _rings.removeAt(i);
    }

    // Screen flashes
    for (int i = _flashes.length - 1; i >= 0; i--) {
      _flashes[i].life -= dt * 4.0;
      if (_flashes[i].life <= 0) _flashes.removeAt(i);
    }

    // Floating texts
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.y += ft.vy * dt;
      ft.life -= dt * 1.8;
      if (ft.life <= 0) _floatingTexts.removeAt(i);
    }

    // Skull rushes
    for (int i = _skullRushes.length - 1; i >= 0; i--) {
      final r = _skullRushes[i];
      r.scale += dt * 8.5;
      r.x += (size.x / 2 - r.x) * dt * 4.0;
      r.y += (size.y / 2 - r.y) * dt * 4.0;
      r.life -= dt * 2.4;
      if (r.life <= 0) _skullRushes.removeAt(i);
    }

    // Score pops
    for (int i = _scorePops.length - 1; i >= 0; i--) {
      _scorePops[i].y -= 28 * dt;
      _scorePops[i].life -= dt * 2.0;
      if (_scorePops[i].life <= 0) _scorePops.removeAt(i);
    }

    // Ambient pile particles
    final cfg = journeyConfig(journeyId);
    if (_pileDisplayTiles.isNotEmpty && _rng.nextDouble() < dt * 3.0) {
      _spawnPileAmbient(cfg.hazard);
    }
  }

  // ─── Input ────────────────────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (_phase != GamePhase.matchWindow) return;
    if (_shuffleLocked) return;

    final pos = event.localPosition;
    final col = ((pos.x - _boardLeft) / (tileW + tileGap)).floor();
    final row = ((pos.y - _boardTop) / (tileH + tileGap)).floor();
    if (col < 0 || col >= _kPyramidMaxCols || row < 0 || row >= _kPyramidRows) return;
    if (!_board.isValidPosition(col, row)) return;

    final topTile = _board.stackAt(col, row).top;
    if (topTile?.isFrosted == true) return;

    final prevCol = _board.selectedCol;
    final prevRow = _board.selectedRow;
    final isSecondTap = _board.selectedTile != null;
    _audio.playTileClick(isSecond: isSecondTap);

    _board.trySelectOrMatch(col, row,
        onMatch: (a, b) {
          _onMatchAt(a, prevCol ?? col, prevRow ?? row, b, col, row);
        },
        onWrongTap: (tile) {
          _wrongTaps++;
          _audio.playWrong();
          onWrongTap?.call();
          _pileShakeAmt = (_pileShakeAmt + 5.0).clamp(0, 20);
          async.Timer(const Duration(milliseconds: 300),
              () => tile.isFlashingRed = false);
        });
  }

  int get wrongTaps => _wrongTaps;

  // ─── Render ───────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Screen flashes (behind everything)
    for (final f in _flashes) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = f.color.withValues(alpha: f.life.clamp(0, 0.35)),
      );
    }

    final shake = _isShaking
        ? sin(DateTime.now().millisecondsSinceEpoch * 0.05) * _shakeAmount
        : 0.0;
    canvas.save();
    canvas.translate(shake, shake * 0.4);

    _drawLivingPile(canvas);
    _drawAllStacks(canvas);
    _drawDroppingTiles(canvas);
    _drawDissolvingTiles(canvas);
    _drawRings(canvas);
    _drawParticles(canvas);
    _drawStarParticles(canvas);
    _drawScorePops(canvas);
    _drawFloatingTexts(canvas);
    _drawSkullRushes(canvas);

    canvas.restore();
  }

  // ─── Living Pile renderer ──────────────────────────────────────────────────

  void _drawLivingPile(Canvas canvas) {
    final pileShake = _pileShakeAmt > 0
        ? sin(DateTime.now().millisecondsSinceEpoch * 0.06) * _pileShakeAmt * 0.6
        : 0.0;

    canvas.save();
    canvas.translate(pileShake, pileShake * 0.3);

    if (_imgPile != null) {
      // Draw the pile asset image, anchored to the bottom of the screen,
      // full width, preserving aspect ratio from the bottom up.
      final img = _imgPile!;
      final imgAspect = img.width / img.height.toDouble();
      final drawW = size.x;
      final drawH = drawW / imgAspect;
      // Sit the image so its bottom aligns with the screen bottom
      final drawTop = size.y - drawH;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, drawTop, drawW, drawH),
        Paint(),
      );
    }

    canvas.restore();
  }

  // ─── Dissolving tile renderer ─────────────────────────────────────────────

  void _drawDissolvingTiles(Canvas canvas) {
    for (final dis in _dissolvingTiles) {
      final alpha = dis.life.clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(dis.x, dis.y);
      if (dis.isStarSpin) canvas.rotate(dis.rotation);
      canvas.scale(dis.scale);
      canvas.translate(-tileW / 2, -tileH / 2);

      if (dis.isStarSpin && _imgStar != null) {
        // Rainbow star tile: just fade cleanly, let the tile's own colours shine
        final tilePaint = Paint()
          ..colorFilter = ColorFilter.matrix([
            1.0, 0, 0, 0, 0,
            0, 1.0, 0, 0, 0,
            0, 0, 1.0, 0, 0,
            0, 0, 0, alpha, 0,
          ]);
        final rr = tileW * 0.13;
        final dst = Rect.fromLTWH(0, 0, tileW, tileH);
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(dst, Radius.circular(rr)));
        canvas.drawImageRect(_imgStar!,
            Rect.fromLTWH(0, 0, _imgStar!.width.toDouble(), _imgStar!.height.toDouble()),
            dst, tilePaint);
        canvas.restore();
        // Rainbow shimmer ring
        final hue = (DateTime.now().millisecondsSinceEpoch % 1800) / 1800.0 * 360.0;
        final ringColor = HSLColor.fromAHSL(alpha * 0.7, hue, 1.0, 0.65).toColor();
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-4, -4, tileW + 8, tileH + 8),
            Radius.circular(tileW * 0.18),
          ),
          Paint()
            ..color = ringColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
      } else {
        // Golden dissolve overlay — tile fades to gold as it lifts
        final tilePaint = Paint()
          ..colorFilter = ColorFilter.matrix([
            1.0 + (1 - alpha) * 0.8, (1 - alpha) * 0.6, 0, 0, (1 - alpha) * 40,
            (1 - alpha) * 0.3, 1.0, 0, 0, (1 - alpha) * 20,
            0, 0, 0.4, 0, 0,
            0, 0, 0, alpha, 0,
          ]);

        if (_useSheet && _tileSheet != null) {
          final sheetW = _tileSheet!.width.toDouble();
          final sheetH = _tileSheet!.height.toDouble();
          final cellW = sheetW / 5;
          final cellH = sheetH / 2;
          final ci = dis.tile.colorIndex % 10;
          final src = Rect.fromLTWH((ci % 5) * cellW, (ci ~/ 5) * cellH, cellW, cellH);
          final dst = Rect.fromLTWH(0, 0, tileW, tileH);
          final rr = tileW * 0.13;
          canvas.save();
          canvas.clipRRect(RRect.fromRectAndRadius(dst, Radius.circular(rr)));
          canvas.drawImageRect(_tileSheet!, src, dst, tilePaint);
          canvas.restore();
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, tileW, tileH), Radius.circular(tileW * 0.13)),
            Paint()..color = const Color(0xFFFFD700).withValues(alpha: alpha * 0.8),
          );
        }

        // Gold shimmer ring that pulses outward
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-3, -3, tileW + 6, tileH + 6),
            Radius.circular(tileW * 0.16),
          ),
          Paint()
            ..color = const Color(0xFFFFD700).withValues(alpha: alpha * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      canvas.restore();
    }
  }

  // ─── Board renderers ───────────────────────────────────────────────────────

  void _drawDroppingTiles(Canvas canvas) {
    for (final dt in _droppingTiles) {
      // Ease out: fast at first, slows near destination
      final t = Curves.easeOut.transform(dt.progress);
      final cx = dt.startX + (dt.targetX + tileW / 2 - dt.startX) * t;
      final cy = dt.startY + (dt.targetY + tileH / 2 - dt.startY) * t;
      final s  = dt.scale;

      // Landing shadow grows as tile arrives
      if (t > 0.5) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dt.targetX + tileW / 2, dt.targetY + tileH * 0.92),
            width:  tileW * ((t - 0.5) * 2.0),
            height: tileH * 0.08 * ((t - 0.5) * 2.0),
          ),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.45 * ((t - 0.5) * 2.0))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Gold trail streaks as tile rises
      if (t < 0.85 && t > 0.05) {
        final prevT = Curves.easeOut.transform((dt.progress - 0.08).clamp(0.0, 1.0));
        final prevCx = dt.startX + (dt.targetX + tileW / 2 - dt.startX) * prevT;
        final prevCy = dt.startY + (dt.targetY + tileH / 2 - dt.startY) * prevT;
        canvas.drawLine(
          Offset(cx, cy), Offset(prevCx, prevCy),
          Paint()
            ..color = const Color(0xFFFFD700).withValues(alpha: 0.18 * (1.0 - t))
            ..strokeWidth = tileW * 0.25 * s
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(s);
      canvas.translate(-tileW / 2, -tileH / 2);
      _drawTile(canvas, dt.tile, 0, 0,
          greyed: false, selected: false, flashing: false);
      canvas.restore();
    }
  }

  void _drawAllStacks(Canvas canvas) {
    for (int r = 0; r < _kPyramidCols.length; r++) {
      for (final c in _kPyramidCols[r]) {
        final x = _boardLeft + c * (tileW + tileGap);
        final y = _boardTop + r * (tileH + tileGap);
        if (_shuffleSpinning && _shuffleSpinAngle > 0) {
          final cx = x + tileW / 2;
          final cy = y + tileH / 2;
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(_shuffleSpinAngle);
          canvas.translate(-cx, -cy);
          _drawStack(canvas, c, r, x, y);
          canvas.restore();
        } else {
          _drawStack(canvas, c, r, x, y);
        }
      }
    }
  }

  void _drawStack(Canvas canvas, int col, int row, double x, double y) {
    final stack = _board.stackAt(col, row);
    if (stack.isEmpty) return;

    if (stack.length >= 2) {
      _drawTile(canvas, stack.second!, x, y,
          greyed: true, selected: false, flashing: false);
    }

    final isSelected = _board.selectedCol == col && _board.selectedRow == row;
    final topX = stack.length >= 2 ? x - stackLayerOffset : x;
    final topY = stack.length >= 2 ? y - stackLayerOffset : y;
    _drawTile(canvas, stack.top!, topX, topY,
        greyed: false, selected: isSelected,
        flashing: stack.top!.isFlashingRed);

    if (stack.hiddenCount > 0) {
      final bx = topX + tileW - 11;
      final by = topY + 11;
      canvas.drawCircle(Offset(bx, by), 9, Paint()..color = const Color(0xCC000000));
      canvas.drawCircle(Offset(bx, by), 9,
          Paint()
            ..color = const Color(0x88FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      final tp = TextPainter(
        text: TextSpan(
            text: '${stack.hiddenCount}',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
    }
  }

  void _drawRings(Canvas canvas) {
    for (final r in _rings) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r.cx, r.cy),
          width: r.baseW + r.radius * 2.2,
          height: r.baseH + r.radius * 1.3,
        ),
        Paint()
          ..color = r.color.withValues(alpha: r.life * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4.0 * r.life).clamp(0.5, 4.5),
      );
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in _particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * p.life.clamp(0, 1),
        Paint()..color = p.color.withValues(alpha: p.life.clamp(0, 1)),
      );
    }
  }

  void _drawStarParticles(Canvas canvas) {
    for (final p in _starParticles) {
      final alpha = p.life.clamp(0.0, 1.0);
      final radius = p.size * alpha;
      final color = HSLColor.fromAHSL(alpha, p.hue, 1.0, 0.65).toColor();
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      _drawStarShape(canvas, radius, Paint()..color = color);
      canvas.restore();
    }
  }

  void _drawStarShape(Canvas canvas, double r, Paint paint) {
    final path = Path();
    final inner = r * 0.42;
    for (int i = 0; i < 10; i++) {
      final angle = (i * pi / 5) - pi / 2;
      final rad = i.isEven ? r : inner;
      final x = cos(angle) * rad;
      final y = sin(angle) * rad;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawScorePops(Canvas canvas) {
    for (final s in _scorePops) {
      final tp = TextPainter(
        text: TextSpan(
          text: '+1',
          style: TextStyle(
            color: const Color(0xFFFFD700).withValues(alpha: s.life.clamp(0, 1)),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(s.x - tp.width / 2, s.y));
    }
  }

  void _drawSkullRushes(Canvas canvas) {
    if (_imgSkullTile == null) return;
    for (final r in _skullRushes) {
      // Fade out in the last 40% of life — becomes translucent as it hits the viewer
      final alpha = (r.life * 2.5).clamp(0.0, 1.0);
      // Gets progressively redder and bleached as it zooms
      final heat = (1.0 - r.life).clamp(0.0, 1.0);
      final paint = Paint()
        ..colorFilter = ColorFilter.matrix([
          1.0 + heat * 0.8, heat * 0.3, 0,         0, heat * 60,
          0,                0.6 - heat * 0.5, 0,    0, 0,
          0,                0,                0.4 - heat * 0.35, 0, 0,
          0,                0,                0,    alpha, 0,
        ]);

      canvas.save();
      canvas.translate(r.x, r.y);
      canvas.scale(r.scale);
      canvas.translate(-tileW / 2, -tileH / 2);
      final src = Rect.fromLTWH(0, 0,
          _imgSkullTile!.width.toDouble(), _imgSkullTile!.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, tileW, tileH);
      canvas.clipRRect(
          RRect.fromRectAndRadius(dst, Radius.circular(tileW * 0.13)));
      canvas.drawImageRect(_imgSkullTile!, src, dst, paint);
      canvas.restore();
    }
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final f in _floatingTexts) {
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            color: f.color.withValues(alpha: f.life.clamp(0, 1)),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(f.x, f.y));
    }
  }

  // ─── Tile renderer ─────────────────────────────────────────────────────────

  static Color _mixColor(Color a, Color b, double t) => Color.fromARGB(
        a.alpha,
        (a.red * (1 - t) + b.red * t).round().clamp(0, 255),
        (a.green * (1 - t) + b.green * t).round().clamp(0, 255),
        (a.blue * (1 - t) + b.blue * t).round().clamp(0, 255),
      );

  ui.Image? _specialImgForTile(Tile tile) {
    if (tile.isSpecial) {
      switch (tile.specialId) {
        case SpecialTileId.slowMo:    return _imgHourglass;
        case SpecialTileId.wildcard:  return _imgStar;
        case SpecialTileId.shuffle:   return _imgChaos;
        default: return null;
      }
    }
    if (tile.isBad) {
      switch (tile.badId) {
        case BadTileId.skull:    return _imgSkullTile;
        case BadTileId.scramble: return _imgChaos;
        default: return null;
      }
    }
    return null;
  }

  void _drawTileWithPaint(Canvas canvas, Tile tile, double x, double y, Paint basePaint) {
    _drawTile(canvas, tile, x, y,
        greyed: false, selected: false, flashing: false, extraPaint: basePaint);
  }

  void _drawTile(Canvas canvas, Tile tile, double x, double y,
      {required bool greyed, required bool selected, required bool flashing,
       Paint? extraPaint}) {
    final rr = tileW * 0.13;
    final rect = Rect.fromLTWH(x, y, tileW, tileH);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rr));

    // Determine image to draw
    ui.Image? img;
    Rect? srcRect;

    final specialImg = _specialImgForTile(tile);
    if (specialImg != null) {
      img = specialImg;
    } else if (_useSheet && _tileSheet != null) {
      img = _tileSheet;
      final sheetW = _tileSheet!.width.toDouble();
      final sheetH = _tileSheet!.height.toDouble();
      final cellW = sheetW / 5;
      final cellH = sheetH / 2;
      final ci = tile.colorIndex % 10;
      srcRect = Rect.fromLTWH((ci % 5) * cellW, (ci ~/ 5) * cellH, cellW, cellH);
    } else {
      img = _tileImages[tile.colorIndex % 10];
    }

    if (img != null) {
      final imgPaint = extraPaint ?? Paint();
      if (greyed) {
        imgPaint.colorFilter = const ColorFilter.matrix([
          0.28, 0.28, 0.28, 0, 0,
          0.28, 0.28, 0.28, 0, 0,
          0.28, 0.28, 0.28, 0, 0,
          0,    0,    0,    0.6, 0,
        ]);
      } else if (flashing) {
        imgPaint.colorFilter = const ColorFilter.matrix([
          1.5, 0,   0,   0, 50,
          0,   0.3, 0.3, 0, 0,
          0.3, 0,   0.3, 0, 0,
          0,   0,   0,   1, 0,
        ]);
      }
      canvas.save();
      canvas.clipRRect(rrect);
      final src = srcRect ?? Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      canvas.drawImageRect(img, src, rect, imgPaint);
      canvas.restore();
    } else {
      // Code-drawn fallback
      if (greyed) {
        canvas.saveLayer(rect.inflate(6), Paint()
          ..colorFilter = const ColorFilter.matrix([
            0.28, 0.28, 0.28, 0, 0,
            0.28, 0.28, 0.28, 0, 0,
            0.28, 0.28, 0.28, 0, 0,
            0,    0,    0,    0.6, 0,
          ]));
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x + 2, y + 3, tileW, tileH), Radius.circular(rr)),
          Paint()..color = _tileDeep);
      canvas.drawRRect(rrect, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_tileLight, _tileBase, _tileDark],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect));
      canvas.drawRRect(rrect, Paint()
        ..color = _tileLight.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      final sw = tileW * 0.065;
      final sp = Paint()
        ..color = _symLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fp = Paint()..color = _symFill..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x + tileW * 0.5, y + tileH * 0.44);
      final s = tileW * 0.44;
      canvas.save();
      canvas.translate(1.0, 1.5);
      _drawSymbolPaths(canvas, tile.colorIndex, s,
          Paint()
            ..color = const Color(0x60000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
          Paint()..color = const Color(0x50000000)..style = PaintingStyle.fill);
      canvas.restore();
      _drawSymbolPaths(canvas, tile.colorIndex, s, sp, fp);
      canvas.restore();
      if (greyed) canvas.restore();
      if (flashing) {
        canvas.drawRRect(rrect, Paint()..color = const Color(0x55FF4400));
      }
    }

    if (selected) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2.5), Radius.circular(rr + 2.5)),
          Paint()
            ..color = const Color(0xFFFFD700)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0);
    }

    // Special shimmer border
    if (!greyed && tile.isSpecial) {
      final ms = DateTime.now().millisecondsSinceEpoch;
      if (tile.specialId == SpecialTileId.wildcard) {
        // Full rainbow cycle for star tile
        final hue = (ms % 2000) / 2000.0 * 360.0;
        final pulse = (sin((ms % 900) / 900.0 * 2 * pi) + 1) / 2;
        final rainbowColor = HSLColor.fromAHSL(1.0, hue, 1.0, 0.6).toColor();
        canvas.drawRRect(rrect, Paint()
          ..color = rainbowColor.withValues(alpha: 0.45 + pulse * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0);
        // Soft outer glow ring
        final outerRRect = RRect.fromRectAndRadius(
            rect.inflate(3.5), Radius.circular(rr + 3.5));
        final glowColor = HSLColor.fromAHSL(1.0, (hue + 90) % 360, 1.0, 0.7).toColor();
        canvas.drawRRect(outerRRect, Paint()
          ..color = glowColor.withValues(alpha: 0.18 + pulse * 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0));
      } else {
        // Gold-to-teal for other special tiles
        final phase = (ms % 1500) / 1500.0;
        final shimmer = (sin(phase * 2 * pi) + 1) / 2;
        final shimmerColor = Color.lerp(
            const Color(0xFFFFD700), const Color(0xFF00CCFF), phase)!;
        canvas.drawRRect(rrect, Paint()
          ..color = shimmerColor.withValues(alpha: 0.4 + shimmer * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
      }
    }

    // Bad tile pulse border (slow red pulse)
    if (!greyed && tile.isBad) {
      final phase = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000.0;
      final pulse = sin(phase * pi) * sin(phase * pi);
      canvas.drawRRect(rrect, Paint()
        ..color = Color.fromARGB((pulse * 200).round(), 200, 20, 20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0);
    }

    if (tile.isFrosted) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0x558BB8D4));
      canvas.drawRRect(rrect, Paint()
        ..color = const Color(0xFF88CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  // ─── Symbol paths (unchanged) ──────────────────────────────────────────────

  void _drawSymbolPaths(Canvas canvas, int idx, double s, Paint sp, Paint fp) {
    switch (idx % 10) {
      case 0: _symSun(canvas, s, sp, fp);
      case 1: _symMoon(canvas, s, sp, fp);
      case 2: _symSpiral(canvas, s, sp);
      case 3: _symHand(canvas, s, sp, fp);
      case 4: _symClaw(canvas, s, sp);
      case 5: _symFern(canvas, s, sp);
      case 6: _symDrop(canvas, s, sp, fp);
      case 7: _symMountain(canvas, s, sp);
      case 8: _symCrystal(canvas, s, sp, fp);
      case 9: _symSkull(canvas, s, sp, fp);
    }
  }

  void _symSun(Canvas canvas, double s, Paint sp, Paint fp) {
    canvas.drawCircle(Offset.zero, s * 0.32, fp);
    canvas.drawCircle(Offset.zero, s * 0.32, sp);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawLine(Offset(cos(a) * s * 0.40, sin(a) * s * 0.40),
          Offset(cos(a) * s * 0.60, sin(a) * s * 0.60), sp);
    }
  }

  void _symMoon(Canvas canvas, double s, Paint sp, Paint fp) {
    final outer = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: s * 0.44));
    final inner = Path()..addOval(Rect.fromCircle(center: Offset(s * 0.22, 0), radius: s * 0.34));
    final crescent = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(crescent, fp);
    canvas.drawPath(crescent, sp);
  }

  void _symSpiral(Canvas canvas, double s, Paint sp) {
    final path = Path();
    for (int i = 0; i <= 80; i++) {
      final t = i / 80.0;
      final a = t * 2.5 * 2 * pi;
      final r = t * s * 0.46;
      final pt = Offset(cos(a) * r, sin(a) * r);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, sp);
  }

  void _symHand(Canvas canvas, double s, Paint sp, Paint fp) {
    final palm = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * 0.04, s * 0.12),
            width: s * 0.66, height: s * 0.48),
        Radius.circular(s * 0.08));
    canvas.drawRRect(palm, fp);
    canvas.drawRRect(palm, sp);
    final fxs = [-s * 0.22, -s * 0.07, s * 0.08, s * 0.22];
    final fhs = [s * 0.42, s * 0.50, s * 0.42, s * 0.32];
    for (int i = 0; i < 4; i++) {
      final fr = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(fxs[i], -s * 0.24),
              width: s * 0.13, height: fhs[i]),
          Radius.circular(s * 0.065));
      canvas.drawRRect(fr, fp);
      canvas.drawRRect(fr, sp);
    }
    final thumb = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(-s * 0.40, s * 0.07),
            width: s * 0.26, height: s * 0.14),
        Radius.circular(s * 0.07));
    canvas.drawRRect(thumb, fp);
    canvas.drawRRect(thumb, sp);
  }

  void _symClaw(Canvas canvas, double s, Paint sp) {
    for (int i = 0; i < 3; i++) {
      final a = -pi * 0.5 + (i - 1) * pi * 0.22;
      final path = Path();
      path.moveTo(cos(a + pi) * s * 0.20, sin(a + pi) * s * 0.20);
      path.quadraticBezierTo(
          cos(a + pi * 0.6) * s * 0.38, sin(a + pi * 0.6) * s * 0.52,
          cos(a) * s * 0.52, sin(a) * s * 0.52);
      canvas.drawPath(path, sp);
    }
  }

  void _symFern(Canvas canvas, double s, Paint sp) {
    canvas.drawLine(Offset(0, s * 0.46), Offset(0, -s * 0.46), sp);
    for (int i = 0; i < 5; i++) {
      final y = s * 0.30 - i * s * 0.18;
      final len = (s * (0.28 - i * 0.03)).clamp(s * 0.10, s * 0.30);
      const a = pi * 0.38;
      canvas.drawLine(Offset(0, y), Offset(-cos(a) * len, y - sin(a) * len), sp);
      canvas.drawLine(Offset(0, y), Offset(cos(a) * len, y - sin(a) * len), sp);
    }
  }

  void _symDrop(Canvas canvas, double s, Paint sp, Paint fp) {
    final path = Path();
    path.moveTo(0, -s * 0.46);
    path.cubicTo(s * 0.36, -s * 0.08, s * 0.36, s * 0.26, 0, s * 0.44);
    path.cubicTo(-s * 0.36, s * 0.26, -s * 0.36, -s * 0.08, 0, -s * 0.46);
    canvas.drawPath(path, fp);
    canvas.drawPath(path, sp);
  }

  void _symMountain(Canvas canvas, double s, Paint sp) {
    final path = Path();
    path.moveTo(-s * 0.46, s * 0.40);
    path.lineTo(0, -s * 0.44);
    path.lineTo(s * 0.46, s * 0.40);
    path.moveTo(-s * 0.46, s * 0.40);
    path.lineTo(-s * 0.16, s * 0.02);
    path.lineTo(s * 0.10, s * 0.40);
    path.moveTo(-s * 0.13, -s * 0.16);
    path.lineTo(0, -s * 0.44);
    path.lineTo(s * 0.13, -s * 0.16);
    canvas.drawPath(path, sp);
  }

  void _symCrystal(Canvas canvas, double s, Paint sp, Paint fp) {
    final path = Path();
    path.moveTo(0, -s * 0.47);
    path.lineTo(s * 0.33, -s * 0.08);
    path.lineTo(s * 0.21, s * 0.46);
    path.lineTo(-s * 0.21, s * 0.46);
    path.lineTo(-s * 0.33, -s * 0.08);
    path.close();
    canvas.drawPath(path, fp);
    canvas.drawPath(path, sp);
    canvas.drawLine(Offset(-s * 0.33, -s * 0.08), Offset(s * 0.33, -s * 0.08), sp);
    canvas.drawLine(Offset(-s * 0.12, -s * 0.08), Offset(0, -s * 0.47), sp);
    canvas.drawLine(Offset(s * 0.12, -s * 0.08), Offset(0, -s * 0.47), sp);
  }

  void _symSkull(Canvas canvas, double s, Paint sp, Paint fp) {
    canvas.drawOval(Rect.fromCenter(
        center: Offset(0, -s * 0.08), width: s * 0.78, height: s * 0.65), fp);
    canvas.drawOval(Rect.fromCenter(
        center: Offset(0, -s * 0.08), width: s * 0.78, height: s * 0.65), sp);
    final eyeFill = Paint()..color = sp.color..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(
        center: Offset(-s * 0.18, -s * 0.10), width: s * 0.24, height: s * 0.22), eyeFill);
    canvas.drawOval(Rect.fromCenter(
        center: Offset(s * 0.18, -s * 0.10), width: s * 0.24, height: s * 0.22), eyeFill);
    final teeth = Path();
    for (int i = -1; i <= 1; i++) {
      final tx = i * s * 0.20;
      teeth.moveTo(tx - s * 0.07, s * 0.23);
      teeth.lineTo(tx, s * 0.38);
      teeth.lineTo(tx + s * 0.07, s * 0.23);
    }
    canvas.drawPath(teeth, sp);
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  @override
  void onRemove() {
    _hazardTimer?.cancel();
    for (final t in _timers) t.cancel();
    _timers.clear();
    _timerManager.dispose();
    super.onRemove();
  }
}

double abs(double v) => v < 0 ? -v : v;
