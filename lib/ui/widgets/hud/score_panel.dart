import 'package:flutter/material.dart';
import '../../../core/enums/win_condition_type.dart';

class ScorePanel extends StatelessWidget {
  final String title;
  final int points;
  final Color color;
  final bool kingdomAttackUnlocked;
  final WinConditionType activeWinCondition;
  final CrossAxisAlignment alignment;

  const ScorePanel({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    required this.kingdomAttackUnlocked,
    required this.activeWinCondition,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text("Points: $points", style: const TextStyle(color: Colors.white)),
        if (kingdomAttackUnlocked) ...[
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              "KINGDOM ATTACK!", 
              style: TextStyle(
                color: Colors.yellow, 
                fontSize: 12, 
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.yellowAccent, blurRadius: 4)]
              )
            ),
          ),
          if (activeWinCondition != WinConditionType.uShape)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                activeWinCondition == WinConditionType.parallel 
                    ? "PARALLEL BLOCKADE" 
                    : "KINGDOM ASSISTED",
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }
}
