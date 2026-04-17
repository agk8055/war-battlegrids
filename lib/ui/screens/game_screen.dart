import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/kingdom_game.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/turn_provider.dart';

import '../../core/enums/game_phase.dart';

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

    // Listen for score increases to show Capture toasts
    ref.listen(simulationProvider, (previous, next) {
      if (previous == null) return;
      if (next.playerScore > previous.playerScore) {
        CaptureToast.show(
          context,
          "PLAYER CAPTURE! +${next.playerScore - previous.playerScore}",
          Colors.blue,
        );
      } else if (next.aiScore > previous.aiScore) {
        CaptureToast.show(
          context,
          "AI CAPTURE! +${next.aiScore - previous.aiScore}",
          Colors.red,
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: Colors.black87,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ScorePanel(
                    title: "PLAYER (BLUE)",
                    points: simulationState.playerScore,
                    color: Colors.blue,
                    kingdomAttackUnlocked:
                        simulationState.playerKingdomAttackUnlocked,
                  ),
                  TurnIndicator(currentTurn: simulationState.currentTurn),
                  ScorePanel(
                    title: "AI (RED)",
                    points: simulationState.aiScore,
                    color: Colors.red,
                    kingdomAttackUnlocked:
                        simulationState.aiKingdomAttackUnlocked,
                    alignment: CrossAxisAlignment.end,
                  ),
                ],
              ),
            ),

            // Flame Game Widget
            Expanded(
              child: Stack(
                children: [
                  GameWidget(game: _game!),

                  if (aiState == AIState.thinking) const AiThinkingOverlay(),

                  if (simulationState.currentPhase == GamePhase.gameOver)
                    GameOverOverlay(
                      winner: simulationState.currentTurn,
                      onReturnToMap: () {
                        // For now just pop back
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
