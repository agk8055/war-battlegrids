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
import '../../campaign/data/kingdoms_data.dart';
import '../../core/services/audio_service.dart';

import '../widgets/hud/score_panel.dart';
import '../widgets/hud/turn_indicator.dart';
import '../widgets/overlays/ai_thinking_overlay.dart';
import '../widgets/overlays/capture_toast.dart';
import '../widgets/overlays/game_over_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  KingdomGame? _game;

  @override
  void initState() {
    super.initState();
    _game = KingdomGame(ref);
    
    // Stop main theme music during match
    Future.microtask(() {
      ref.read(audioServiceProvider).stopMusic();
    });
  }

  @override
  void dispose() {
    // Resume main theme music when leaving match
    ref.read(audioServiceProvider).playMainTheme();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulationState = ref.watch(simulationProvider);
    final aiState = ref.watch(aiStateProvider);

    final settings = ref.watch(gameSettingsProvider);
    final isMultiplayer = settings.mode == GameMode.multiplayer;
    
    final campaignState = ref.watch(campaignProvider);
    final selectedKingdom = campaignState.selectedKingdomId != null 
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    final p1Name = isMultiplayer ? settings.player1Name : settings.player1Name;
    final p1Symbol = settings.player1Symbol;

    final p2Name = isMultiplayer 
        ? settings.player2Name 
        : (selectedKingdom?.name ?? "AI");
    final p2Symbol = isMultiplayer 
        ? settings.player2Symbol 
        : (selectedKingdom?.symbolAsset ?? "assets/icons/eagle.png");
    final p2Color = isMultiplayer 
        ? Colors.red 
        : (selectedKingdom?.primaryColor ?? Colors.red);

    // Listen for score increases to show Capture toasts
    ref.listen(simulationProvider, (previous, next) {
      if (previous == null) return;
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
          p2Color,
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

          // 2. HUD Layer (Safe Area)
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Player Score Panel
                      _buildOverlayContainer(
                        child: ScorePanel(
                          title: p1Name,
                          symbolAsset: p1Symbol,
                          points: simulationState.playerScore,
                          color: Colors.blue,
                          kingdomAttackUnlocked:
                              simulationState.playerKingdomAttackUnlocked,
                          activeWinCondition: simulationState.playerActiveWinCondition,
                        ),
                      ),

                      // Turn Indicator
                      TurnIndicator(currentTurn: simulationState.currentTurn, mode: settings.mode),

                      // AI Score Panel
                      _buildOverlayContainer(
                        child: ScorePanel(
                          title: p2Name,
                          symbolAsset: p2Symbol,
                          points: simulationState.aiScore,
                          color: p2Color,
                          kingdomAttackUnlocked:
                              simulationState.aiKingdomAttackUnlocked,
                          activeWinCondition: simulationState.aiActiveWinCondition,
                          alignment: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Overlays (Full Screen - Outside SafeArea)
          if (aiState == AIState.thinking) 
            const Positioned.fill(child: AiThinkingOverlay()),

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

  Widget _buildOverlayContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: child,
    );
  }
}
