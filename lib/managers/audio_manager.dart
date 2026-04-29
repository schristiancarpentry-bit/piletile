import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._();
  factory AudioManager() => _instance;
  AudioManager._();

  bool soundEnabled = true;
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(String name) async {
    if (!soundEnabled) return;
    try {
      await _player.play(AssetSource('audio/$name.mp3'), volume: 0.8);
    } catch (_) {}
  }

  void toggleSound() => soundEnabled = !soundEnabled;

  Future<void> playThud() => play('thud');
  Future<void> playCrack() => play('crack');
  Future<void> playWrong() => play('wrong');
  Future<void> playCountdown() => play('countdown');
  Future<void> playSpecial() => play('special');
  Future<void> playBad() => play('bad');
  Future<void> playGameOver() => play('gameover');
  Future<void> playBonfire() => play('bonfire');
  Future<void> playLevelUp() => play('levelup');
  Future<void> playDrop() => play('drop');
  Future<void> playWind() => play('wind');
}
