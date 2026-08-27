import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/kingdom_game.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/online_provider.dart';
import '../../core/enums/connection_type.dart';
import '../../core/enums/game_mode.dart';
import 'bluetooth_lobby_screen.dart';
import 'online_lobby_screen.dart';
import 'settings_screen.dart';

import '../../core/enums/game_phase.dart';
import '../../core/enums/turn.dart';
import '../../campaign/campaign_manager.dart';
import '../../core/services/audio_service.dart';
import '../widgets/hud/battle_hud_header.dart';
import 'post_battle_screen.dart';
import '../widgets/overlays/capture_toast.dart';
import '../widgets/overlays/pause_overlay.dart';
import '../widgets/overlays/game_over_overlay.dart';
import '../../simulation/game_simulation.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  KingdomGame? _game;
  bool _isPaused = false;
  bool _showPostBattle = false;

  @override
  void initState() {
    super.initState();
    _game = KingdomGame(ref, onToast: _showGameToast);
    // Ensure music is playing
    ref.read(audioServiceProvider).playMainTheme();
  }

  void _showGameToast(String message, Color color) {
    if (!mounted) return;
    CaptureToast.show(context, message, color);
  }


  void _togglePause() {
    final connectionType = ref.read(connectionTypeProvider);

    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _game?.pauseEngine();
        if (connectionType == ConnectionType.bluetooth) {
          ref.read(bluetoothProvider.notifier).sendPause(true);
        } else if (connectionType == ConnectionType.online) {
          ref.read(onlineProvider.notifier).sendPause(true);
        }
      } else {
        _game?.resumeEngine();
        if (connectionType == ConnectionType.bluetooth) {
          ref.read(bluetoothProvider.notifier).sendPause(false);
        } else if (connectionType == ConnectionType.online) {
          ref.read(onlineProvider.notifier).sendPause(false);
        }
      }
    });
  }

  void _showDisconnectionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161410),
        title: const Text('BATTLE DISRUPTED', style: TextStyle(color: Colors.redAccent, letterSpacing: 2)),
        content: const Text('Your opponent has abandoned the battlefield or lost connection.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Return to lobby, but don't disconnect (Host keeps room)
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const OnlineLobbyScreen()),
              );
            },
            child: const Text('RETURN TO LOBBY', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _handleAbandon() {
    final settings = ref.read(gameSettingsProvider);
    final connectionType = ref.read(connectionTypeProvider);

    if (connectionType == ConnectionType.bluetooth) {
      ref.read(bluetoothProvider.notifier).sendAbandon();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BluetoothLobbyScreen()),
      );
    } else if (connectionType == ConnectionType.online) {
      // Send abandonment to peer so they get the disrupted dialog
      ref.read(onlineProvider.notifier).sendAbandon();
      // Host stays in room, Client will see "Host Left" presence event
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnlineLobbyScreen()),
      );
    } else if (settings.mode == GameMode.story) {
      Navigator.of(context).popUntil((route) => route.settings.name == '/overworld');
    } else {
      Navigator.of(context).popUntil((route) => route.settings.name == '/map_selection');
    }
  }

  void _handleRematch() {
    ref.read(simulationProvider.notifier).reset();
    setState(() {
      _showPostBattle = false;
      _game = KingdomGame(ref, onToast: _showGameToast);
    });
  }

  void _handleReturn() {
    final settings = ref.read(gameSettingsProvider);
    final simulationState = ref.read(simulationProvider);

    if (settings.mode == GameMode.story) {
      if (simulationState.winner == Turn.player) {
        final campaignState = ref.read(campaignProvider);
        if (campaignState.selectedKingdomId != null) {
          ref.read(campaignProvider.notifier).conquerKingdom(
                campaignState.selectedKingdomId!,
              );
        }
      }
      Navigator.of(context).popUntil((route) => route.settings.name == '/overworld');
    } else if (settings.mode == GameMode.multiplayer) {
      final connectionType = ref.read(connectionTypeProvider);
      if (connectionType == ConnectionType.bluetooth) {
        // Reset gameStarted flag so we can start again
        ref.read(bluetoothProvider.notifier).setGameStarted(false);
        
        // Return to lobby
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const BluetoothLobbyScreen(),
          ),
        );
      } else if (connectionType == ConnectionType.online) {
        // Reset gameStarted flag so we can start again
        ref.read(onlineProvider.notifier).setGameStarted(false);
        
        // Return to lobby
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnlineLobbyScreen(),
          ),
        );
      } else {
        // Same-device multiplayer: return to mode selection
        Navigator.of(context).popUntil((route) => route.settings.name == '/multiplayer_mode');
      }
    } else {
      Navigator.of(context).popUntil((route) => route.settings.name == '/map_selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final simulationState = ref.watch(simulationProvider);
    final settings = ref.watch(gameSettingsProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final onlineState = ref.watch(onlineProvider);
    final connectionType = ref.watch(connectionTypeProvider);

    // Shared Pause Logic: if peer paused, we show pause too
    bool peerPaused = false;
    if (connectionType == ConnectionType.bluetooth) {
      peerPaused = bluetoothState.isPeerPaused;
    } else if (connectionType == ConnectionType.online) {
      peerPaused = onlineState.isPeerPaused;
    }

    final effectivePaused = _isPaused || peerPaused;

    // Listen for peer abandonment
    ref.listen(bluetoothProvider, (previous, next) {
      if (connectionType == ConnectionType.bluetooth && previous?.gameStarted == true && !next.gameStarted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const BluetoothLobbyScreen()),
        );
      }
      
      if (connectionType == ConnectionType.bluetooth) {
         if (next.isPeerPaused && !(previous?.isPeerPaused ?? false)) {
           _game?.pauseEngine();
         } else if (!next.isPeerPaused && (previous?.isPeerPaused ?? false) && !_isPaused) {
           _game?.resumeEngine();
         }
      }
    });

    ref.listen(onlineProvider, (previous, next) {
      if (connectionType == ConnectionType.online && previous?.gameStarted == true && !next.gameStarted) {
        if (next.status == OnlineStatus.disconnected) {
           _showDisconnectionDialog();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnlineLobbyScreen()),
          );
        }
      }
      
      if (connectionType == ConnectionType.online) {
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
      bool isHost = true;
      if (connectionType == ConnectionType.bluetooth) {
        isHost = bluetoothState.isHost;
      } else if (connectionType == ConnectionType.online) {
        isHost = onlineState.isHost;
      }

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

    final isGameOver = simulationState.currentPhase == GamePhase.gameOver || 
                       simulationState.currentPhase == GamePhase.draw;

    return _buildBaseGame(context, simulationState, settings, effectivePaused, isGameOver, connectionType);
  }

  Widget _buildBaseGame(
    BuildContext context,
    GameSimulation simulationState,
    GameSettings settings,
    bool effectivePaused,
    bool isGameOver,
    ConnectionType connectionType,
  ) {
    final isMultiplayer = settings.mode == GameMode.multiplayer;
    final isBluetooth = connectionType == ConnectionType.bluetooth;
    final isOnline = connectionType == ConnectionType.online;
    final isSameDevice = isMultiplayer && !isBluetooth && !isOnline;

    final canRematch = (settings.mode == GameMode.story || isSameDevice);

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

          // Game Over Sequence:
          // 1. Cinematic Victory / Defeat Overlay (3-4 secs or tap to continue)
          // 2. Full Post Battle Stats Screen
          if (isGameOver) ...[
            if (!_showPostBattle)
              GameOverOverlay(
                winner: simulationState.winner,
                mode: settings.mode,
                onContinue: () {
                  if (mounted) {
                    setState(() {
                      _showPostBattle = true;
                    });
                  }
                },
              )
            else
              Positioned.fill(
                child: PostBattleScreen(
                  stats: simulationState.generateBattleStats(),
                  mode: settings.mode,
                  onContinue: _handleReturn,
                  onRematch: canRematch ? _handleRematch : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}


