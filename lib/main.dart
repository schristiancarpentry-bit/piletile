import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'managers/progress_manager.dart';
import 'managers/ad_manager.dart';
import 'managers/audio_manager.dart';
import 'theme/journey_themes.dart';
import 'screens/comic_intro_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journey_map_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/level_complete_screen.dart';
import 'screens/journey_complete_screen.dart';
import 'screens/bonfire_screen.dart';
import 'managers/level_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await ProgressManager().init();
  await AdManager().init();
  await AudioManager().initAudio();
  runApp(const PileTileApp());
}

class PileTileApp extends StatelessWidget {
  const PileTileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tile Pile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const AppRouter(),
    );
  }
}

enum Screen {
  splash, home, journeyMap, levelMap, game, gameOver,
  levelComplete, bonfire, journeyComplete
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> with WidgetsBindingObserver {
  Screen _screen = ProgressManager().hasSeenIntro ? Screen.home : Screen.splash;
  int _journeyId = 1;
  int _level = 1;
  int _wrongTaps = 0;
  int _pairsCleared = 0;
  int _roundsSurvived = 0;
  int _diedOnLevel = 1;
  int _diedOnRound = 1;
  int _journeyMapKey = 0;

  final _progress = ProgressManager();
  final _audio = AudioManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _audio.stopMenuMusic();
      _audio.stopLevelScreenMusic();
      _audio.stopGameMusic();
    }
  }

  void _goTo(Screen s) => setState(() {
        if (s == Screen.journeyMap) _journeyMapKey++;
        _screen = s;
      });

  Future<void> _onLevelComplete(int wrongTaps) async {
    _wrongTaps = wrongTaps;
    final ceiling = LevelManager.pairCeiling(_level);
    _roundsSurvived = ceiling;
    _pairsCleared = ceiling * (ceiling + 1) ~/ 2;

    final stars = wrongTaps == 0 ? 3 : (wrongTaps <= 3 ? 2 : 1);
    await _progress.saveHighestLevel(_journeyId, _level);
    await _progress.saveStars(_journeyId, _level, stars);

    if (isBonfireLevel(_journeyId, _level)) {
      await _progress.saveBonfire(_journeyId, _level);
      await _progress.addReviveStone();
      _audio.playBonfire();
      _goTo(Screen.bonfire);
    } else if (_level >= 10) {
      await _progress.addReviveStone();
      _audio.playLevelUp();
      _goTo(Screen.journeyComplete);
    } else {
      _audio.playLevelUp();
      _goTo(Screen.levelComplete);
    }
  }

  Future<void> _onSuddenDeath(int round) async {
    _audio.stopGameMusic();
    _diedOnLevel = _level;
    _diedOnRound = round;
    final bonfire = _progress.getBonfireLevel(_journeyId);
    final dropTo = max(bonfire, 1);
    await _progress.saveCurrentLevel(_journeyId, dropTo);
    _level = dropTo;
    _audio.playDrop();

    final showAd = AdManager().shouldShowAd;
    _goTo(Screen.gameOver);
    if (showAd) {
      Future.delayed(const Duration(milliseconds: 500), () {
        AdManager().showInterstitial();
      });
    }
  }

  Widget _buildScreen() {
    switch (_screen) {
      case Screen.splash:
        return ComicIntroScreen(onDone: () => _goTo(Screen.home));

      case Screen.home:
        return HomeScreen(
          onPlay: () => _goTo(Screen.journeyMap),
          onStory: () => _goTo(Screen.splash),
        );

      case Screen.journeyMap:
        return JourneyMapScreen(
          key: ValueKey(_journeyMapKey),
          onBack: () => _goTo(Screen.home),
          onJourneySelected: (id) {
            _journeyId = id;
            _level = _progress.getCurrentLevel(_journeyId);
            _goTo(Screen.levelMap);
          },
        );

      case Screen.levelMap:
        return LevelMapScreen(
          journeyId: _journeyId,
          onBack: () => _goTo(Screen.journeyMap),
          onLevelSelected: (jId, lvl) {
            _journeyId = jId;
            _level = lvl;
            _wrongTaps = 0;
            _goTo(Screen.game);
          },
        );

      case Screen.game:
        return GameScreen(
          key: ValueKey(
              'game-$_journeyId-$_level-${DateTime.now().millisecondsSinceEpoch}'),
          journeyId: _journeyId,
          level: _level,
          onBack: () {
            _audio.stopGameMusic();
            _goTo(Screen.levelMap);
          },
          onSuddenDeath: _onSuddenDeath,
          onLevelComplete: _onLevelComplete,
        );

      case Screen.gameOver:
        final bonfire = _progress.getBonfireLevel(_journeyId);
        return GameOverScreen(
          diedOnRound: _diedOnRound,
          diedOnLevel: _diedOnLevel,
          droppingToLevel: _level,
          bonfireLevel: bonfire,
          onContinue: () {
            _wrongTaps = 0;
            _goTo(Screen.game);
          },
        );

      case Screen.levelComplete:
        return LevelCompleteScreen(
          level: _level,
          pairsCleared: _pairsCleared,
          roundsSurvived: _roundsSurvived,
          wrongTaps: _wrongTaps,
          onNextLevel: () {
            _level++;
            _wrongTaps = 0;
            _progress.saveCurrentLevel(_journeyId, _level);
            _goTo(Screen.game);
          },
          onJourneyMap: () => _goTo(Screen.journeyMap),
        );

      case Screen.bonfire:
        return BonfireScreen(
          journeyId: _journeyId,
          level: _level,
          onRest: () {
            if (_level >= 10) {
              _goTo(Screen.journeyComplete);
            } else {
              _level++;
              _wrongTaps = 0;
              _progress.saveCurrentLevel(_journeyId, _level);
              _goTo(Screen.game);
            }
          },
        );

      case Screen.journeyComplete:
        return JourneyCompleteScreen(
          journeyId: _journeyId,
          onContinue: () => _goTo(Screen.journeyMap),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _screen == Screen.home || _screen == Screen.splash,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_screen == Screen.game) {
          _goTo(Screen.levelMap);
        } else {
          _goTo(Screen.journeyMap);
        }
      },
      child: _buildScreen(),
    );
  }
}
