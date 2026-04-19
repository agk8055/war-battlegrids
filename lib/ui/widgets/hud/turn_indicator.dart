import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/turn.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';

class TurnIndicator extends ConsumerWidget {
  final Turn currentTurn;
  final GameMode mode;

  const TurnIndicator({super.key, required this.currentTurn, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayer = currentTurn == Turn.player;
    final isMultiplayer = mode == GameMode.multiplayer;
    final settings = ref.watch(gameSettingsProvider);

    String text;
    if (isMultiplayer) {
      text = isPlayer ? '${settings.player1Name} TURN' : '${settings.player2Name} TURN';
    } else {
      text = isPlayer ? 'PLAYER TURN' : 'AI TURN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isPlayer ? Colors.blue.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlayer ? Colors.blueAccent : Colors.redAccent, 
          width: 2
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isPlayer ? Colors.blueAccent : Colors.redAccent,
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
