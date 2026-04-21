import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/kingdom_game.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../core/enums/game_mode.dart';

import '../../core/enums/game_phase.dart';
import '../../core/enums/turn.dart';
import '../../campaign/campaign_manager.dart';
import '../../core/services/audio_service.dart';

import '../widgets/hud/battle_hud_header.dart';
import '../widgets/overlays/ai_thinking_overlay.dart';
import '../widgets/overlays/capture_toast.dart';
import '../widgets/overlays/game_over_overlay.dart';
import '../widgets/overlays/pause_overlay.dart';
import 'settings_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  KingdomGame? _game;
  late AudioService _audioService;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _game = KingdomGame(ref);
    _audioService = ref.read(audioServiceProvider);
    
    // Stop main theme music during match
    Future.microtask(() {
      if (!mounted) return;
      _audioService.stopMusicForMatch();
    });
  }

  @override
  void dispose() {
    // Resume main theme music when leaving match
    _audioService.resumeMusicAfterMatch();
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _game?.pauseEngine();
      } else {
        _game?.resumeEngine();
      }
    });
  }

  void _quitBattle(GameMode mode) {
    _game?.resumeEngine(); // Ensure engine is not frozen
    if (mode == GameMode.story) {
      Navigator.of(context).popUntil((route) => route.settings.name == '/overworld');
    } else {
      Navigator.of(context).popUntil((route) => route.settings.name == '/map_selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final simulationState = ref.watch(simulationProvider);
    final aiState = ref.watch(aiStateProvider);
    final settings = ref.watch(gameSettingsProvider);

    // Listen for score increases to show Capture toasts
    ref.listen(simulationProvider, (previous, next) {
      if (previous == null) return;
      
      // Determine Player names for toast messages
      final p1Name = settings.player1Name;
      final p2Name = settings.mode == GameMode.multiplayer ? settings.player2Name : "AI";

      if (next.playerScore > previous.playerScore) {
        CaptureToast.show(
          context,
          "${p1Name.toUpperCase()} CAPTURE! +${next.playerScore - previous.playerScore}",
          Colors.blue,
        );
      } else if (next.aiScore > previous.aiScore) {
        CaptureToast.show(
          context,
          "${p2Name.toUpperCase()} CAPTURE! +${next.aiScore - previous.aiScore}",
          Colors.redAccent,
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Game Layer (Full Screen)
          Positioned.fill(
            child: GameWidget(game: _game!),
          ),

          // 2. HUD Layer (Top Aligned)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BattleHudHeader(
              onPausePressed: _togglePause,
            ),
          ),

          // 3. Overlays (Full Screen - Outside SafeArea)
          if (aiState == AIState.thinking && !_isPaused) 
            const Positioned.fill(child: AiThinkingOverlay()),

          if (_isPaused)
            PauseOverlay(
              onResume: _togglePause,
              onSettings: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              onQuit: () => _quitBattle(settings.mode),
            ),

          if (simulationState.currentPhase == GamePhase.gameOver)
            Positioned.fill(
              child: GameOverOverlay(
                winner: simulationState.currentTurn,
                mode: settings.mode,
                onReturnToMap: () {
                  if (settings.mode == GameMode.story) {
                    if (simulationState.currentTurn == Turn.player) {
                      final campaignState = ref.read(campaignProvider);
                      if (campaignState.selectedKingdomId != null) {
                        ref.read(campaignProvider.notifier).conquerKingdom(
                              campaignState.selectedKingdomId!,
                            );
                      }
                    }
                    Navigator.of(context).popUntil((route) => route.settings.name == '/overworld');
                  } else {
                    Navigator.of(context).popUntil((route) => route.settings.name == '/map_selection');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
