import 'package:flutter/material.dart';
import '../../../core/enums/turn.dart';

class TurnIndicator extends StatelessWidget {
  final Turn currentTurn;

  const TurnIndicator({super.key, required this.currentTurn});

  @override
  Widget build(BuildContext context) {
    final isPlayer = currentTurn == Turn.player;
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
        "${isPlayer ? 'PLAYER' : 'AI'} TURN",
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
