import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._();
  factory AudioManager() => _instance;
  AudioManager._();

  bool soundEnabled = true;

  // Clicks: AudioPool (SoundPool) — zero focus management, zero state machine, rapid fire safe
  AudioPool? _clickPool;

  // All AudioPlayer instances use AudioFocus.none — no focus competition between players,
  // no ducking callbacks, no illegal-state crashes from onAudioFocusChange on Android 16.
  final AudioPlayer _sfxPlayer     = AudioPlayer(); // short SFX (crack, thud, wrong…)
  final AudioPlayer _specialPlayer = AudioPlayer(); // special tile sounds (wildcard, chaos, slowmo)
  final AudioPlayer _skullPlayer   = AudioPlayer(); // skull laugh (concurrent with SFX)
  final AudioPlayer _musicPlayer   = AudioPlayer(); // menu / level-select music
  final AudioPlayer _gamePlayer    = AudioPlayer(); // in-game music loop

  Timer? _specialStopTimer;
  Timer? _skullStopTimer;
  String? _currentGameTrack;

  // SFX: sonification usage, no audio focus — mixes freely with music, no callbacks
  static final _sfxCtx = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  // Music: music usage, no audio focus — never ducked or paused by our own SFX
  static final _musicCtx = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  // Call once from main() before the app starts
  Future<void> initAudio() async {
    try {
      _clickPool = await AudioPool.createFromAsset(
        path: 'audio/tile_click.mp3',
        maxPlayers: 4,
      );
    } catch (_) {}
    for (final p in [_sfxPlayer, _specialPlayer, _skullPlayer]) {
      try { await p.setReleaseMode(ReleaseMode.stop); } catch (_) {}
    }
  }

  // ─── Generic SFX ────────────────────────────────────────────────────────────

  Future<void> play(String name) async {
    if (!soundEnabled) return;
    try {
      await _sfxPlayer.play(
        AssetSource('audio/$name.mp3'),
        volume: 0.8,
        ctx: _sfxCtx,
      );
    } catch (_) {}
  }

  // ─── Music ──────────────────────────────────────────────────────────────────

  Future<void> playMenuMusic() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(
          AssetSource('audio/menu.mp3'), volume: 0.55, ctx: _musicCtx);
    } catch (_) {}
  }

  Future<void> stopMenuMusic() async {
    try { await _musicPlayer.stop(); } catch (_) {}
  }

  Future<void> playLevelScreenMusic() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.play(
          AssetSource('audio/level_screen.mp3'), volume: 0.55, ctx: _musicCtx);
    } catch (_) {}
  }

  Future<void> stopLevelScreenMusic() async {
    try { await _musicPlayer.stop(); } catch (_) {}
  }

  Future<void> playGameMusic(int journeyId) async {
    final files = {1: 'bedrock'};
    final name = files[journeyId];
    if (name == null) return;
    if (_currentGameTrack == name && _gamePlayer.state == PlayerState.playing) return;
    _currentGameTrack = name;
    try { await _gamePlayer.stop(); } catch (_) {}
    try { await _gamePlayer.setReleaseMode(ReleaseMode.loop); } catch (_) {}
    try {
      await _gamePlayer.play(
          AssetSource('audio/$name.mp3'), volume: 0.5, ctx: _musicCtx);
    } catch (_) {}
  }

  Future<void> stopGameMusic() async {
    _currentGameTrack = null;
    try { await _gamePlayer.stop(); } catch (_) {}
  }

  // ─── Clicks ─────────────────────────────────────────────────────────────────

  void toggleSound() => soundEnabled = !soundEnabled;

  Future<void> playTileClick({bool isSecond = false}) async {
    if (!soundEnabled) return;
    try {
      await _clickPool?.start(volume: isSecond ? 0.85 : 0.75);
    } catch (_) {}
  }

  // ─── Special tile sounds (dedicated player — concurrent with SFX) ────────────

  Future<void> playWildcardSound() async {
    if (!soundEnabled) return;
    try {
      await _specialPlayer.play(
          AssetSource('audio/wildcard.mp3'), volume: 0.85, ctx: _sfxCtx);
    } catch (_) {}
  }

  Future<void> playChaosSound() async {
    if (!soundEnabled) return;
    try {
      await _specialPlayer.play(
          AssetSource('audio/chaos.mp3'), volume: 0.85, ctx: _sfxCtx);
    } catch (_) {}
  }

  Future<void> playSlowMoSound() async {
    if (!soundEnabled) return;
    _specialStopTimer?.cancel();
    try {
      await _specialPlayer.play(
        AssetSource('audio/slowmo.mp3'),
        volume: 0.85,
        position: const Duration(seconds: 1),
        ctx: _sfxCtx,
      );
    } catch (_) {}
    _specialStopTimer = Timer(const Duration(milliseconds: 3000), () {
      try { _specialPlayer.stop(); } catch (_) {}
    });
  }

  Future<void> playSkullLaugh() async {
    if (!soundEnabled) return;
    _skullStopTimer?.cancel();
    try { await _skullPlayer.stop(); } catch (_) {}
    try {
      await _skullPlayer.play(
        AssetSource('audio/skull_laugh.mp3'),
        volume: 0.9,
        ctx: _sfxCtx,
      );
    } catch (_) {}
    _skullStopTimer = Timer(const Duration(milliseconds: 3000), () {
      try { _skullPlayer.stop(); } catch (_) {}
    });
  }

  // ─── Named SFX shortcuts ────────────────────────────────────────────────────

  Future<void> playThud()     => play('thud');
  Future<void> playCrack()    => play('crack');
  Future<void> playWrong()    => play('wrong');
  Future<void> playCountdown()=> play('countdown');
  Future<void> playSpecial()  => play('special');
  Future<void> playBad()      => play('bad');
  Future<void> playGameOver() => play('gameover');
  Future<void> playBonfire()  => play('bonfire');
  Future<void> playLevelUp()  => play('levelup');
  Future<void> playDrop()     => play('drop');
  Future<void> playWind()     => play('wind');
  Future<void> playFreeze()   => play('freeze');
  Future<void> playInferno()  => play('inferno');
}
