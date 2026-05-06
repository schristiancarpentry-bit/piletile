import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../managers/progress_manager.dart';

class ComicIntroScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ComicIntroScreen({super.key, required this.onDone});

  @override
  State<ComicIntroScreen> createState() => _ComicIntroScreenState();
}

class _ComicIntroScreenState extends State<ComicIntroScreen> {
  static const _panels = [
    'assets/images/comic/panel_1.png',
    'assets/images/comic/panel_2.png',
    'assets/images/comic/panel_3.png',
    'assets/images/comic/panel_4.png',
    'assets/images/comic/panel_5.png',
    'assets/images/comic/panel_6.png',
    'assets/images/comic/panel_7.png',
  ];

  static const _captions = [
    'Three worlds. Three Piles.\nEach one balanced, ordered, and complete.',
    'Then there was the fourth world.\n\nNo Pile. No tiles. Just Grumblor.',
    'For ten thousand years he watched the others.\nOrdered. Purposeful. Complete.\n\nHe was none of those things.',
    'Then one Tuesday...\nhe stopped being patient about it.',
    'He erupted from the earth, roared at all three worlds,\nand went on a rampage.\n\nThis was called The Great Rumble.',
    'When the dust settled, all the tiles lay in one enormous heap.\n\nGrumblor looked at what he\'d done.\n\nHe felt terrible.',
    '"...I need your help."',  // Grumblor's line — styled differently
  ];

  // Adjust these once the ElevenLabs audio is generated and timed.
  // Each value is how long (ms) the panel shows BEFORE fading to the next.
  static const _panelDurations = [6000, 6000, 7500, 6000, 8000, 8000, 5500];

  static const _crossfadeDuration = Duration(milliseconds: 450);

  int _currentPanel = 0;
  double _panelOpacity = 0.0;
  double _captionOpacity = 0.0;
  bool _transitioning = false;

  Timer? _panelTimer;
  Timer? _captionTimer;
  Timer? _transitionTimer;

  final _audio = AudioPlayer();
  final _grumblorAudio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    ProgressManager().markIntroSeen();
    _showPanel(0);
    Future.delayed(const Duration(milliseconds: 1500), _playNarration);
  }

  Future<void> _playNarration() async {
    try {
      await _audio.setReleaseMode(ReleaseMode.stop);
      await _audio.play(AssetSource('audio/intro_narration.mp3'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> _playGrumblor() async {
    try {
      await _grumblorAudio.setReleaseMode(ReleaseMode.stop);
      await _grumblorAudio.play(AssetSource('audio/intro_grumblor.m4a'), volume: 1.0);
    } catch (_) {}
  }

  void _showPanel(int index) {
    if (!mounted) return;
    if (index >= _panels.length) { _finish(); return; }

    _captionTimer?.cancel();
    _panelTimer?.cancel();

    setState(() {
      _currentPanel = index;
      _panelOpacity = 0.0;
      _captionOpacity = 0.0;
      _transitioning = false;
    });

    // Fade panel in
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _panelOpacity = 1.0);
    });

    // Grumblor speaks on the last panel
    if (index == _panels.length - 1) {
      Future.delayed(const Duration(milliseconds: 600), _playGrumblor);
    }

    // Caption appears 700ms after panel fades in
    _captionTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _captionOpacity = 1.0);
    });

    // Schedule transition to next panel
    _panelTimer = Timer(Duration(milliseconds: _panelDurations[index]), () {
      _transitionToPanel(index + 1);
    });
  }

  void _transitionToPanel(int next) {
    if (!mounted || _transitioning) return;
    _transitioning = true;

    // Fade out current panel and caption
    setState(() {
      _panelOpacity = 0.0;
      _captionOpacity = 0.0;
    });

    // After fade-out, show next panel
    _transitionTimer = Timer(_crossfadeDuration, () => _showPanel(next));
  }

  void _finish() {
    widget.onDone();
  }

  void _skip() {
    _panelTimer?.cancel();
    _captionTimer?.cancel();
    _transitionTimer?.cancel();
    _audio.stop();
    _grumblorAudio.stop();
    _finish();
  }

  @override
  void dispose() {
    _panelTimer?.cancel();
    _captionTimer?.cancel();
    _transitionTimer?.cancel();
    _audio.dispose();
    _grumblorAudio.dispose();
    super.dispose();
  }

  bool get _isLastPanel => _currentPanel == _panels.length - 1;

  @override
  Widget build(BuildContext context) {
    final caption = _currentPanel < _captions.length
        ? _captions[_currentPanel]
        : '';
    final topPad = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: _skip,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Panel image ──────────────────────────────────────────────
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _panelOpacity,
                duration: _crossfadeDuration,
                child: Image.asset(
                  _panels[_currentPanel],
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
                ),
              ),
            ),

            // ── Gradient backing for caption ─────────────────────────────
            if (caption.isNotEmpty)
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: 200,
                child: AnimatedOpacity(
                  opacity: _captionOpacity,
                  duration: const Duration(milliseconds: 400),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Caption text ─────────────────────────────────────────────
            if (caption.isNotEmpty)
              Positioned(
                left: 28, right: 28, bottom: 58,
                child: AnimatedOpacity(
                  opacity: _captionOpacity,
                  duration: const Duration(milliseconds: 400),
                  child: _isLastPanel
                      // Last panel: Grumblor's voice — bold, centred, stone feel
                      ? Text(
                          caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.4,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(color: Color(0xFFD4A76A), blurRadius: 24),
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        )
                      // Other panels: narrator voice — warm, smaller
                      : Text(
                          caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE8D5A0),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.65,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),

            // ── Skip button ───────────────────────────────────────────────
            Positioned(
              top: topPad + 14,
              right: 18,
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'SKIP',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // ── Panel progress dots ───────────────────────────────────────
            Positioned(
              bottom: 22,
              left: 0, right: 0,
              child: AnimatedOpacity(
                opacity: _panelOpacity,
                duration: _crossfadeDuration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_panels.length, (i) {
                    final active = i == _currentPanel;
                    final done   = i < _currentPanel;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: done
                            ? const Color(0xFFD4A76A).withValues(alpha: 0.6)
                            : active
                                ? const Color(0xFFD4A76A)
                                : Colors.white24,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
