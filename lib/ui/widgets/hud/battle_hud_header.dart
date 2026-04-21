import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/enums/turn.dart';
import '../../../providers/simulation_provider.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../campaign/campaign_manager.dart';
import '../../../campaign/data/kingdoms_data.dart';
import 'score_panel.dart';

class BattleHudHeader extends ConsumerWidget {
  final VoidCallback onPausePressed;

  const BattleHudHeader({
    super.key,
    required this.onPausePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationState = ref.watch(simulationProvider);
    final settings = ref.watch(gameSettingsProvider);
    final campaignState = ref.watch(campaignProvider);

    final isMultiplayer = settings.mode == GameMode.multiplayer;
    final selectedKingdom = campaignState.selectedKingdomId != null 
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    final p1Name = settings.player1Name;
    final p1Symbol = settings.player1Symbol;

    final p2Name = isMultiplayer 
        ? settings.player2Name 
        : (selectedKingdom?.name ?? "AI");
    final p2Symbol = isMultiplayer 
        ? settings.player2Symbol 
        : (selectedKingdom?.symbolAsset ?? 'assets/icons/eagle.png');
    final p2Color = isMultiplayer 
        ? Colors.red 
        : (selectedKingdom?.primaryColor ?? Colors.red);

    final isP1Turn = simulationState.currentTurn == Turn.player;
    final isP2Turn = simulationState.currentTurn == Turn.ai;

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Player Score Section
            Expanded(
              flex: 3,
              child: ScorePanel(
                title: p1Name,
                symbolAsset: p1Symbol,
                points: simulationState.playerScore,
                color: Colors.blue,
                kingdomAttackUnlocked: simulationState.playerKingdomAttackUnlocked,
                activeWinCondition: simulationState.playerActiveWinCondition,
                isActiveTurn: isP1Turn,
              ),
            ),

            // Center Control Section
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.center,
                child: IconButton(
                  onPressed: onPausePressed,
                  icon: const Icon(Icons.pause_circle_filled, color: Colors.white70, size: 40),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),

            // AI/Player 2 Score Section
            Expanded(
              flex: 3,
              child: ScorePanel(
                title: p2Name,
                symbolAsset: p2Symbol,
                points: simulationState.aiScore,
                color: p2Color,
                kingdomAttackUnlocked: simulationState.aiKingdomAttackUnlocked,
                activeWinCondition: simulationState.aiActiveWinCondition,
                alignment: CrossAxisAlignment.end,
                isActiveTurn: isP2Turn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
