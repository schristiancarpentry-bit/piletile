import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'managers/progress_manager.dart';
import 'managers/ad_manager.dart';
import 'managers/audio_manager.dart';
import 'theme/journey_themes.dart';
import 'screens/home_screen.dart';
import 'screens/journey_map_screen.dart';
import 'screens/level_map_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_over_screen.dart';
import 'screens/level_complete_screen.dart';
import 'screens/journey_complete_screen.dart';
import 'screens/bonfire_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await ProgressManager().init();
  await AdManager().init();
  runApp(const PileTileApp());
}

class PileTileApp extends StatelessWidget {
  const PileTileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PileTile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const AppRouter(),
    );
  }
}

enum Screen { home, journeyMap, levelMap, game, gameOver, levelComplete, bonfire, journeyComplete }

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  Screen _screen = Screen.home;
  int _journeyId = 1;
  int _level = 1;
  int _wrongTaps = 0;
  int _pairsCleared = 0;
  int _roundsSurvived = 0;
  int _diedOnRound = 1;
  final _progress = ProgressManager();
  final _audio = AudioManager();

  void _goTo(Screen s) => setState(() => _screen = s);

  Future<void> _onLevelComplete() async {
    final ceiling = 5 + _level * 5;
    _pairsCleared = ceiling;
    _roundsSurvived = ceiling;
    await _progress.saveHighestLevel(_journeyId, _level);

    final randomBonfire = _progress.getRandomBonfireLevel(_journeyId);
    if (isBonfireLevel(_journeyId, _level, randomBonfire)) {
      await _progress.saveBonfire(_journeyId, _level);
      _audio.playBonfire();
      _goTo(Screen.bonfire);
    } else if (_level >= 13) {
      _audio.playLevelUp();
      _goTo(Screen.journeyComplete);
    } else {
      _audio.playLevelUp();
      _goTo(Screen.levelComplete);
    }
  }

  Future<void> _onSuddenDeath() async {
    _diedOnRound = _level;
    final bonfire = _progress.getBonfireLevel(_journeyId);
    final dropTo = max(bonfire, 1);
    await _progress.saveCurrentLevel(_journeyId, dropTo);
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
      case Screen.home:
        return HomeScreen(onPlay: () => _goTo(Screen.journeyMap));

      case Screen.journeyMap:
        return JourneyMapScreen(onJourneySelected: (id) {
          _journeyId = id;
          if (id >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${getJourneyTheme(id).name} coming soon!'),
                backgroundColor: Colors.black87,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          _level = _progress.getCurrentLevel(_journeyId);
          if (_journeyId == 9) _ensureRandomBonfire();
          _goTo(Screen.levelMap);
        });

      case Screen.levelMap:
        return LevelMapScreen(
          journeyId: _journeyId,
          onLevelSelected: (jId, lvl) {
            _journeyId = jId;
            _level = lvl;
            _wrongTaps = 0;
            _goTo(Screen.game);
          },
        );

      case Screen.game:
        return GameScreen(
          key: ValueKey('game-$_journeyId-$_level-${DateTime.now().millisecondsSinceEpoch}'),
          journeyId: _journeyId,
          level: _level,
          onSuddenDeath: _onSuddenDeath,
          onLevelComplete: _onLevelComplete,
        );

      case Screen.gameOver:
        final bonfire = _progress.getBonfireLevel(_journeyId);
        return GameOverScreen(
          diedOnRound: _diedOnRound,
          diedOnLevel: _level,
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
            if (_level >= 13) {
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

  void _ensureRandomBonfire() {
    if (_progress.getRandomBonfireLevel(_journeyId) == null) {
      final rng = Random();
      final lvl = 2 + rng.nextInt(11);
      _progress.setRandomBonfireLevel(_journeyId, lvl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _screen == Screen.home,
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
