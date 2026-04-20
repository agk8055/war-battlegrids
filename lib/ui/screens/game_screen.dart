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
  }

  @override
  Widget build(BuildContext context) {
    final simulationState = ref.watch(simulationProvider);
    final aiState = ref.watch(aiStateProvider);

    final settings = ref.watch(gameSettingsProvider);
    final isMultiplayer = settings.mode == GameMode.multiplayer;

    // Listen for score increases to show Capture toasts
    ref.listen(simulationProvider, (previous, next) {
      if (previous == null) return;
      if (next.playerScore > previous.playerScore) {
        CaptureToast.show(
          context,
          "${isMultiplayer ? settings.player1Name : 'PLAYER'} CAPTURE! +${next.playerScore - previous.playerScore}",
          Colors.blue,
        );
      } else if (next.aiScore > previous.aiScore) {
        CaptureToast.show(
          context,
          "${isMultiplayer ? settings.player2Name : 'AI'} CAPTURE! +${next.aiScore - previous.aiScore}",
          Colors.red,
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for game feel
      body: SafeArea(
        child: Stack(
          children: [
            // 1. The Game Layer
            Positioned.fill(
              child: GameWidget(game: _game!),
            ),

            // 2. Fixed Overlays (Top HUD)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player Score Panel (Top Left)
                  _buildOverlayContainer(
                    child: ScorePanel(
                      title: isMultiplayer ? settings.player1Name : "PLAYER",
                      points: simulationState.playerScore,
                      color: Colors.blue,
                      kingdomAttackUnlocked:
                          simulationState.playerKingdomAttackUnlocked,
                      activeWinCondition: simulationState.playerActiveWinCondition,
                    ),
                  ),

                  // Turn Indicator (Top Center) - Has its own background
                  TurnIndicator(currentTurn: simulationState.currentTurn, mode: settings.mode),

                  // AI Score Panel (Top Right)
                  _buildOverlayContainer(
                    child: ScorePanel(
                      title: isMultiplayer ? settings.player2Name : "AI",
                      points: simulationState.aiScore,
                      color: Colors.red,
                      kingdomAttackUnlocked:
                          simulationState.aiKingdomAttackUnlocked,
                      activeWinCondition: simulationState.aiActiveWinCondition,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Other Overlays (Thinking, Game Over)
            if (aiState == AIState.thinking) const AiThinkingOverlay(),

            if (simulationState.currentPhase == GamePhase.gameOver)
              GameOverOverlay(
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
                    // Multiplayer mode: return to map selection
                    Navigator.of(context).popUntil((route) => route.settings.name == '/map_selection');
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Helper to wrap HUD components in a consistent, readable background container.
  Widget _buildOverlayContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7), // Semi-transparent black
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: child,
    );
  }
}
