import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/piletile_game.dart';
import '../managers/level_manager.dart';
import '../managers/audio_manager.dart';
import '../managers/progress_manager.dart';
import '../config/journey_config.dart';

class GameScreen extends StatefulWidget {
  final int journeyId;
  final int level;
  final VoidCallback? onBack;
  final void Function(int round) onSuddenDeath;
  final void Function(int wrongTaps) onLevelComplete;

  const GameScreen({
    super.key,
    required this.journeyId,
    required this.level,
    this.onBack,
    required this.onSuddenDeath,
    required this.onLevelComplete,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  PileTileGame? _game;
  GamePhase _phase = GamePhase.dropping;
  int _round = 1;
  int _ceiling = 10;
  double _timer = 0;
  int _countdown = 3;
  double _topInset = 0;
  double _bottomInset = 0;

  // Grumblor
  String _grumlorImage = 'assets/images/grumblor/grumblor_idle.png';
  bool _grumlorRaging = false;

  // Maps expression names to confirmed existing assets
  static const _expressionAssets = {
    'idle':      'assets/images/grumblor/grumblor_idle.png',
    'rage':      'assets/images/grumblor/grumblor_rage.png',
    'fuming':    'assets/images/grumblor/grumblor_fuming.png',
    'scream':    'assets/images/grumblor/grumblor_scream.png',
    'celebrate': 'assets/images/grumblor/grumblor_celebrate.png',
    'angry':     'assets/images/grumblor/grumblor_angry.png',
    'shocked':   'assets/images/grumblor/grumblor_shocked.png',
    // Mapped to best available substitute
    'flinch':    'assets/images/grumblor/grumblor_worried.png',
    'reluctant': 'assets/images/grumblor/grumblor_thinking.png',
    'throw':     'assets/images/grumblor/grumblor_shocked.png',
    'shrug':     'assets/images/grumblor/grumblor_sideeye.png',
  };

  static String _assetFor(String expression) =>
      _expressionAssets[expression] ?? 'assets/images/grumblor/grumblor_idle.png';

  // Speech bubble
  String? _speechText;

  // Bonfire start
  int _startRound = 1;
  bool _bonfireGreetingShown = false;

  // Special state badges
  bool _slowMoActive = false;
  bool _shuffling = false;

  // Tutorial
  int _tutorialStep = 0; // 0=off, 1=tap a tile, 2=tap its match
  bool _tutorialActive = false;

  // Revive stone prompt
  bool _revivePromptActive = false;
  double _reviveCountdown = 6.0;
  Timer? _reviveTimer;

  final _audio = AudioManager();
  final _progress = ProgressManager();
  final _rng = Random();

  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _audio.playGameMusic(widget.journeyId);
    _tutorialActive =
        widget.journeyId == 1 && widget.level == 1 && !_progress.hasSeenTutorial;
    if (_tutorialActive) _tutorialStep = 1;

    // Bonfire round: first attempt = full ramp; every retry = skip to challenge
    final isFirstAttempt =
        !_progress.hasAttemptedLevel(widget.journeyId, widget.level);
    _startRound = isFirstAttempt
        ? 1
        : LevelManager.bonfireRound(widget.level);
    _progress.markLevelAttempted(widget.journeyId, widget.level);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _reviveTimer?.cancel();
    super.dispose();
  }

  void _showSpeech(List<String> lines, {int durationMs = 2800}) {
    if (lines.isEmpty) return;
    final text = lines[_rng.nextInt(lines.length)];
    setState(() => _speechText = text);
    Future.delayed(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => _speechText = null);
    });
  }

  void _onGrumlorExpression(String expression) {
    switch (expression) {
      case 'rage':
        _showSpeech([
          "Don't look at me like that.",
          "...tch.",
          "I am not reacting. I am supervising.",
          "That was almost certainly your fault.",
        ]);
      case 'celebrate':
        _showSpeech([
          "Don't get used to it.",
          "...Fine. Acceptable.",
          "I suppose that was not entirely terrible.",
          "...Well done. Don't make it weird.",
        ]);
      case 'scream':
        _showSpeech([
          "...Well. That happened.",
          "I was not holding my breath. I was just standing here.",
          "This is fine.",
        ], durationMs: 3500);
      case 'fuming':
        _showSpeech([
          "I caused this. I know. Moving on.",
          "...Don't.",
          "I am not panicking. You are panicking.",
        ]);
      case 'angry':
        _showSpeech([
          "I am not watching. I am merely standing here.",
          "...Hurry up.",
          "Take your time. I have been here ten thousand years.",
        ]);
      case 'flinch':
        _showSpeech([
          "...I didn't flinch.",
          "That was a strategic blink.",
          "...tch.",
        ]);
      case 'reluctant':
        _showSpeech([
          "I suppose you have one of my stones.",
          "...Fine. I was saving that. But fine.",
          "Don't read into this.",
          "This changes nothing between us.",
        ], durationMs: 5000);
      case 'throw':
        _showSpeech([
          "There. Happy now? Don't waste it.",
          "...That cost me something. Remember that.",
          "One. Stone. Don't squander it.",
        ], durationMs: 3000);
      case 'shrug':
        _showSpeech([
          "...Your choice. I offered.",
          "Fine. I'll keep my stone then.",
          "I wasn't holding my breath.",
        ]);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;
    final mq = MediaQuery.of(context);
    _topInset = mq.padding.top;
    _bottomInset = mq.padding.bottom;
    _ceiling = LevelManager.pairCeiling(widget.level);
    _game = PileTileGame(
      journeyId: widget.journeyId,
      level: widget.level,
      startRound: _startRound,
      topInset: _topInset,
      bottomInset: _bottomInset,
      onPhaseChange: (phase, data) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _phase = phase;
                _round = data['round'] as int? ?? _round;
                _ceiling = data['ceiling'] as int? ?? _ceiling;
                _timer = (data['timer'] as double?) ?? _timer;
                _countdown = (data['countdown'] as int?) ?? _countdown;
                _slowMoActive = (data['slowmo'] as bool?) ?? _slowMoActive;
                _updateGrumblor();

                // Bonfire greeting — shown once when starting from a skipped round
                if (phase == GamePhase.dropping &&
                    _round == _startRound &&
                    _startRound > 1 &&
                    !_bonfireGreetingShown) {
                  _bonfireGreetingShown = true;
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (mounted) {
                      _showSpeech([
                        "...Back already? The Pile remembers.",
                        "I kept your place. Don't read into it.",
                        "The early rounds bore me anyway.",
                        "...The Pile was expecting you.",
                        "Round $_round. Don't waste it.",
                      ], durationMs: 3200);
                      setState(() => _grumlorImage = _assetFor('sideeye'));
                      Future.delayed(const Duration(milliseconds: 2000), () {
                        if (mounted) setState(_updateGrumblor);
                      });
                    }
                  });
                }

                // Speech on key phase transitions
                if (phase == GamePhase.matchWindow && _round == 1) {
                  _showSpeech(["I am not watching. I am merely standing here."]);
                }
                if (phase == GamePhase.roundComplete) {
                  _showSpeech([
                    "I suppose that was acceptable.",
                    "...Good. Fine. Whatever.",
                    "That tile was always going to fall your way. Eventually.",
                    "...Mm.",
                  ]);
                }
                if (phase == GamePhase.levelComplete) {
                  _showSpeech([
                    "Don't get used to it.",
                    "...Fine. Well done.",
                    "I knew you could do it. I was not worried. At all.",
                  ], durationMs: 3500);
                }

                // Tutorial step advances
                if (_tutorialActive) {
                  if (phase == GamePhase.matchWindow && _round == 1) {
                    _tutorialStep = 2;
                  } else if (phase == GamePhase.roundComplete && _round == 2) {
                    _tutorialStep = 0;
                    _progress.markTutorialSeen();
                    _tutorialActive = false;
                  }
                }
              });
            }
          });
        }
      },
      onWrongTap: () {
        if (mounted && !_grumlorRaging) {
          setState(() {
            _grumlorRaging = true;
            _grumlorImage = _assetFor('rage');
          });
          _onGrumlorExpression('rage');
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _grumlorRaging = false;
                _updateGrumblor();
              });
            }
          });
        }
      },
      onGrumlorEvent: (expression, durationMs) {
        if (mounted && !_grumlorRaging) {
          setState(() {
            _grumlorImage = _assetFor(expression);
          });
          _onGrumlorExpression(expression);
          Future.delayed(Duration(milliseconds: durationMs), () {
            if (mounted) setState(() => _updateGrumblor());
          });
        }
      },
      onGameEvent: (event) {
        if (!mounted) return;
        switch (event) {
          case 'slowmo_start':
            setState(() => _slowMoActive = true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _slowMoActive = false);
            });
          case 'skull_laugh':
            _audio.playSkullLaugh();
          case 'shuffle_start':
            setState(() => _shuffling = true);
          case 'shuffle_end':
            setState(() => _shuffling = false);
        }
      },
      onReviveOffer: () {
        if (mounted) setState(() => _startRevivePrompt());
      },
      onSuddenDeath: (r) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onSuddenDeath(r)),
      onLevelComplete: (wt) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onLevelComplete(wt)),
    );
  }

  void _startRevivePrompt() {
    _revivePromptActive = true;
    _reviveCountdown = 6.0;
    _reviveTimer?.cancel();
    _reviveTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _reviveCountdown -= 0.1;
        if (_reviveCountdown <= 0) {
          _reviveCountdown = 0;
          t.cancel();
          _dismissRevivePrompt();
          _game?.declineRevive(timeout: true);
        }
      });
    });
  }

  void _dismissRevivePrompt() {
    _reviveTimer?.cancel();
    _reviveTimer = null;
    _revivePromptActive = false;
  }

  void _onReviveAccept() {
    _dismissRevivePrompt();
    setState(() {});
    _game?.acceptRevive();
  }

  void _onReviveDecline() {
    _dismissRevivePrompt();
    setState(() {});
    _game?.declineRevive();
  }

  void _updateGrumblor() {
    if (_grumlorRaging) return;
    if (_phase == GamePhase.suddenDeath) {
      _grumlorImage = _assetFor('scream');
    } else if (_phase == GamePhase.levelComplete) {
      _grumlorImage = _assetFor('celebrate');
    } else if (_round >= 16) {
      _grumlorImage = _assetFor('fuming');
    } else if (_round >= 6) {
      _grumlorImage = _assetFor('angry');
    } else {
      _grumlorImage = _assetFor('idle');
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) return const SizedBox.expand();
    final cfg = journeyConfig(widget.journeyId);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(cfg.backgroundAsset, fit: BoxFit.cover),
          ),
          GameWidget(game: game),
          _buildHUD(cfg),
          _buildGrumblor(),
          if (_speechText != null) _buildSpeechBubble(),
          if (_phase == GamePhase.countdown) _buildCountdown(cfg),
          if (_slowMoActive) _buildSlowMoBadge(),
          if (_shuffling) _buildShuffleOverlay(),
          if (_tutorialActive && _tutorialStep > 0) _buildTutorialOverlay(cfg),
          if (_revivePromptActive) _buildRevivePrompt(cfg),
        ],
      ),
    );
  }

  // ─── HUD ────────────────────────────────────────────────────────────────────

  Widget _buildHUD(JourneyConfig cfg) {
    final accent = cfg.accentColor;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      if (widget.onBack != null)
                        GestureDetector(
                          onTap: () { _audio.stopGameMusic(); widget.onBack?.call(); },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: accent, size: 18),
                          ),
                        )
                      else
                        const SizedBox(width: 44),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEVEL ${widget.level}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Round $_round of $_ceiling',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildStoneHud(accent),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              // Round progress dots
              _buildRoundDots(cfg),
              // Full-width timer bar
              _buildTimerBar(cfg),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Round progress dots ─────────────────────────────────────────────────────

  Widget _buildRoundDots(JourneyConfig cfg) {
    if (_ceiling <= 0) return const SizedBox.shrink();
    final accent = cfg.accentColor;
    const maxDots = 20;
    final display = _ceiling.clamp(1, maxDots);
    final hasMore = _ceiling > maxDots;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(display, (i) {
            final roundNum = i + 1;
            final done = roundNum < _round;
            final current = roundNum == _round;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: current ? 8 : 5,
              height: current ? 8 : 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? accent.withValues(alpha: 0.75)
                    : current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                boxShadow: current
                    ? [BoxShadow(color: accent, blurRadius: 6, spreadRadius: 1)]
                    : null,
              ),
            );
          }),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('…',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      height: 1)),
            ),
        ],
      ),
    );
  }

  // ─── Grumblor ────────────────────────────────────────────────────────────────

  Widget _buildGrumblor() {
    return Positioned(
      right: 0,
      bottom: _bottomInset,
      child: IgnorePointer(
        child: SizedBox(
          width: 110,
          height: 110,
          child: Image.asset(
            _grumlorImage,
            fit: BoxFit.contain,
            alignment: Alignment.bottomRight,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  // ─── Speech bubble ──────────────────────────────────────────────────────────

  Widget _buildSpeechBubble() {
    return Positioned(
      right: 90,
      bottom: _bottomInset + 60,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 220),
          builder: (_, v, child) =>
              Opacity(opacity: v, child: Transform.scale(scale: 0.85 + v * 0.15, child: child)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1208).withValues(alpha: 0.94),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(3),
              ),
              border: Border.all(
                color: const Color(0xFFD4A76A).withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _speechText ?? '',
              style: const TextStyle(
                color: Color(0xFFE8D5A0),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tutorial overlay ────────────────────────────────────────────────────────

  Widget _buildTutorialOverlay(JourneyConfig cfg) {
    final String heading;
    final String sub;
    if (_tutorialStep == 1) {
      heading = 'TAP A TILE';
      sub = 'Select any tile on the board';
    } else {
      heading = 'TAP ITS MATCH';
      sub = 'Find the same tile and tap it';
    }

    return Positioned(
      left: 0,
      right: 0,
      top: _topInset + 106,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cfg.accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    color: cfg.accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Countdown overlay ───────────────────────────────────────────────────────

  Widget _buildCountdown(JourneyConfig cfg) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.65),
              border: Border.all(color: cfg.accentColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: cfg.accentColor.withValues(alpha: 0.4),
                    blurRadius: 20),
              ],
            ),
            child: Center(
              child: Text(
                '$_countdown',
                style: TextStyle(
                  color: cfg.accentColor,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Slow-mo badge ───────────────────────────────────────────────────────────

  Widget _buildSlowMoBadge() {
    return Positioned(
      top: _topInset + 104,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF002233),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00CCFF), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0xFF00CCFF), blurRadius: 10),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⏳', style: TextStyle(fontSize: 13)),
                SizedBox(width: 5),
                Text('SLOW-MO',
                    style: TextStyle(
                        color: Color(0xFF00CCFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shuffle overlay ─────────────────────────────────────────────────────────

  Widget _buildShuffleOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00CCAA), width: 1.5),
            ),
            child: const Text(
              '🔀  SHUFFLING...',
              style: TextStyle(
                color: Color(0xFF00CCAA),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Timer bar ───────────────────────────────────────────────────────────────

  Widget _buildTimerBar(JourneyConfig cfg) {
    final isActive = _phase == GamePhase.matchWindow;
    final total = LevelManager.matchWindowSeconds(_round, level: widget.level);
    final frac = isActive ? (_timer / total).clamp(0.0, 1.0) : 0.0;

    final Color fillColor = _slowMoActive
        ? const Color(0xFF00CCFF)
        : frac > 0.5
            ? Color.lerp(const Color(0xFFFFD700), const Color(0xFF50C878),
                (frac - 0.5) * 2)!
            : Color.lerp(Colors.red, const Color(0xFFFFD700), frac * 2)!;

    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        return SizedBox(
          height: 10,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Track
              Container(color: Colors.black.withValues(alpha: 0.45)),
              // Fill
              if (isActive)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fillColor,
                      boxShadow: [
                        BoxShadow(
                          color: fillColor.withValues(alpha: 0.7),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              // Slow-mo shimmer sweep
              if (isActive && _slowMoActive && frac > 0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment(
                          -1.5 + _shimmerCtrl.value * 4.0, 0),
                      end: Alignment(
                          -0.8 + _shimmerCtrl.value * 4.0, 0),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ).createShader(rect),
                    blendMode: BlendMode.srcATop,
                    child: Container(color: fillColor),
                  ),
                ),
              // Slow-mo sparkle particles
              if (isActive && _slowMoActive && frac > 0)
                ...List.generate(5, (i) {
                  final phase = (_shimmerCtrl.value + i * 0.2) % 1.0;
                  final xFrac = (i * 0.22 + _shimmerCtrl.value * 0.3) % frac;
                  final alpha = (sin(phase * pi) * 0.9).clamp(0.0, 1.0);
                  final size = 4.0 + sin(phase * pi) * 3.0;
                  return Positioned(
                    left: xFrac * MediaQuery.of(context).size.width,
                    top: 5 - size / 2,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: alpha),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00CCFF).withValues(alpha: alpha * 0.9),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              // Leading edge glow dot
              if (isActive && frac > 0.01)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 4,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(color: fillColor, blurRadius: 8, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Stone HUD icon ──────────────────────────────────────────────────────────

  Widget _buildStoneHud(Color accent) {
    final count = _progress.stoneCount;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/revive_stone.png',
              width: 18, height: 18, fit: BoxFit.contain),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Revive prompt ───────────────────────────────────────────────────────────

  Widget _buildRevivePrompt(JourneyConfig cfg) {
    final accent = cfg.accentColor;
    final frac = (_reviveCountdown / 6.0).clamp(0.0, 1.0);
    final countdownColor = frac > 0.5
        ? const Color(0xFF50C878)
        : frac > 0.25
            ? const Color(0xFFFFD700)
            : Colors.red;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/revive_stone.png',
                  width: 72, height: 72, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text(
                'USE A REVIVE STONE?',
                style: TextStyle(
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_progress.stoneCount} stone${_progress.stoneCount == 1 ? '' : 's'} remaining',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
              // Countdown bar
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white12,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: frac,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: countdownColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_reviveCountdown.ceil()}s',
                style: TextStyle(
                  color: countdownColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              // Accept button
              GestureDetector(
                onTap: _onReviveAccept,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 12),
                    ],
                  ),
                  child: Text(
                    '"Fine. Take it."',
                    style: TextStyle(
                      color: accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Decline button
              GestureDetector(
                onTap: _onReviveDecline,
                child: const Text(
                  'Keep it',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

