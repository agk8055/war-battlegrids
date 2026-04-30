import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/enums/turn.dart';
import '../../../providers/simulation_provider.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/bluetooth_provider.dart';
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
    final bluetoothState = ref.watch(bluetoothProvider);

    final isMultiplayer = settings.mode == GameMode.multiplayer;
    final isBluetooth = bluetoothState.status == BluetoothStatus.connected;
    
    // In same-device multiplayer, we treat it like 'Host' so P1 is Left (Turn.player), P2 is Right (Turn.ai)
    final bool effectiveIsHost = isMultiplayer ? (!isBluetooth || bluetoothState.isHost) : true;

    final selectedKingdom = campaignState.selectedKingdomId != null 
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    final String p1Name;
    final String p1Symbol;
    final int p1ColorVal;

    final String p2Name;
    final String p2Symbol;
    final int p2ColorVal;

    if (isMultiplayer) {
      if (effectiveIsHost) {
        p1Name = settings.player1Name;
        p1Symbol = settings.player1Symbol;
        p1ColorVal = settings.player1Color;

        p2Name = settings.player2Name;
        p2Symbol = settings.player2Symbol;
        p2ColorVal = settings.player2Color;
      } else {
        // Joiner device: player1 in settings is Me (Joiner), player2 is Peer (Host)
        // We want Host on Left (Turn.player), Joiner on Right (Turn.ai)
        p1Name = settings.player2Name; // Host
        p1Symbol = settings.player2Symbol;
        p1ColorVal = settings.player2Color;

        p2Name = settings.player1Name; // Joiner
        p2Symbol = settings.player1Symbol;
        p2ColorVal = settings.player1Color;
      }
    } else {
      p1Name = settings.player1Name;
      p1Symbol = settings.player1Symbol;
      p1ColorVal = settings.player1Color;

      p2Name = selectedKingdom?.name ?? "AI";
      p2Symbol = selectedKingdom?.symbolAsset ?? 'assets/icons/eagle.png';
      p2ColorVal = selectedKingdom?.primaryColor.toARGB32() ?? Colors.red.toARGB32();
    }

    final p1Color = Color(p1ColorVal);
    final p2Color = Color(p2ColorVal);

    // Turn.player is Host (P1), Turn.ai is Joiner (P2)
    final p1IsActive = simulationState.currentTurn == Turn.player;
    final p1Score = simulationState.playerScore;
    final p1KingdomAttackUnlocked = simulationState.playerKingdomAttackUnlocked;
    final p1ActiveWinCondition = simulationState.playerActiveWinCondition;

    final p2IsActive = simulationState.currentTurn == Turn.ai;
    final p2Score = simulationState.aiScore;
    final p2KingdomAttackUnlocked = simulationState.aiKingdomAttackUnlocked;
    final p2ActiveWinCondition = simulationState.aiActiveWinCondition;

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                points: p1Score,
                color: p1Color,
                kingdomAttackUnlocked: p1KingdomAttackUnlocked,
                activeWinCondition: p1ActiveWinCondition,
                isActiveTurn: p1IsActive,
              ),
            ),

            // Center Control Section
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.center,
                child: IconButton(
                  onPressed: onPausePressed,
                  icon: const Icon(Icons.pause_circle_filled, color: Colors.white70, size: 32),
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
                points: p2Score,
                color: p2Color,
                kingdomAttackUnlocked: p2KingdomAttackUnlocked,
                activeWinCondition: p2ActiveWinCondition,
                alignment: CrossAxisAlignment.end,
                isActiveTurn: p2IsActive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
