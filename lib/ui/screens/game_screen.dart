import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/kingdom_game.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../core/enums/game_mode.dart';
import 'multiplayer_mode_selection_screen.dart';
import 'bluetooth_lobby_screen.dart';

import '../../core/enums/game_phase.dart';
import '../../core/enums/turn.dart';
import '../../campaign/campaign_manager.dart';
import '../../core/services/audio_service.dart';
import '../widgets/hud/battle_hud_header.dart';
import '../widgets/overlays/game_over_overlay.dart';
import '../widgets/overlays/capture_toast.dart';
import '../widgets/overlays/pause_overlay.dart';
import 'settings_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  KingdomGame? _game;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _game = KingdomGame(ref);
    // Ensure music is playing
    ref.read(audioServiceProvider).playMainTheme();
  }

  void _togglePause() {
    final settings = ref.read(gameSettingsProvider);
    final isMultiplayer = settings.mode == GameMode.multiplayer;

    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _game?.pauseEngine();
        if (isMultiplayer) {
          ref.read(bluetoothProvider.notifier).sendPause(true);
        }
      } else {
        _game?.resumeEngine();
        if (isMultiplayer) {
          ref.read(bluetoothProvider.notifier).sendPause(false);
        }
      }
    });
  }

  void _handleAbandon() {
    final settings = ref.read(gameSettingsProvider);
    final isMultiplayer = settings.mode == GameMode.multiplayer;

    if (isMultiplayer) {
      ref.read(bluetoothProvider.notifier).sendAbandon();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BluetoothLobbyScreen()),
      );
    } else if (settings.mode == GameMode.story) {
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
    final bluetoothState = ref.watch(bluetoothProvider);

    // Shared Pause Logic: if peer paused, we show pause too
    final effectivePaused = _isPaused || (settings.mode == GameMode.multiplayer && bluetoothState.isPeerPaused);

    // Listen for peer abandonment
    ref.listen(bluetoothProvider, (previous, next) {
      if (settings.mode == GameMode.multiplayer && previous?.gameStarted == true && !next.gameStarted) {
        // Peer abandoned or something triggered game end
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const BluetoothLobbyScreen()),
        );
      }
      
      // Update engine pause state based on peer
      if (settings.mode == GameMode.multiplayer) {
         if (next.isPeerPaused && !(previous?.isPeerPaused ?? false)) {
           _game?.pauseEngine();
         } else if (!next.isPeerPaused && (previous?.isPeerPaused ?? false) && !_isPaused) {
           _game?.resumeEngine();
         }
      }
    });

    // Listen for score increases to show Capture toasts
    ref.listen(simulationProvider, (previous, next) {
      if (previous == null) return;
      
      // Visual sync
      _game?.forceSync();
      
      // Determine Player names for toast messages
      final isMultiplayer = settings.mode == GameMode.multiplayer;
      final isHost = ref.read(bluetoothProvider).isHost;
      final p1Name = settings.player1Name;
      final p2Name = isMultiplayer ? settings.player2Name : "AI";

      if (next.playerScore > previous.playerScore) {
        // Turn.player (Host) captured
        final name = (isMultiplayer && !isHost) ? p2Name : p1Name;
        final color = (isMultiplayer && !isHost) ? Color(settings.player2Color) : Color(settings.player1Color);
        CaptureToast.show(
          context,
          "${name.toUpperCase()} CAPTURE! +${next.playerScore - previous.playerScore}",
          color,
        );
      } else if (next.aiScore > previous.aiScore) {
        // Turn.ai (Joiner/AI) captured
        final name = (isMultiplayer && !isHost) ? p1Name : p2Name;
        final color = (isMultiplayer && !isHost) ? Color(settings.player1Color) : Color(settings.player2Color);
        CaptureToast.show(
          context,
          "${name.toUpperCase()} CAPTURE! +${next.aiScore - previous.aiScore}",
          color,
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Game World
          if (_game != null) GameWidget(game: _game!),

          // HUD Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BattleHudHeader(
              onPausePressed: _togglePause,
            ),
          ),

          // Loading/Thinking Overlay
          if (aiState == AIState.thinking && !effectivePaused)
            const Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white70),
                    SizedBox(height: 12),
                    Text(
                      "AI IS THINKING...",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Pause Overlay
          if (effectivePaused)
            PauseOverlay(
              onResume: _isPaused ? _togglePause : () {}, // Only local can resume if they paused it
              onQuit: _handleAbandon,
              onSettings: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),

          // Game Over Overlay
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
                  } else if (settings.mode == GameMode.multiplayer) {
                    // Reset gameStarted flag so we can start again
                    ref.read(bluetoothProvider.notifier).setGameStarted(false);
                    
                    // Return to lobby
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const BluetoothLobbyScreen(),
                      ),
                    );
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
