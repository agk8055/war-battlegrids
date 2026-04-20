import 'package:flutter/material.dart';
import '../../../core/enums/win_condition_type.dart';

class ScorePanel extends StatelessWidget {
  final String title;
  final int points;
  final Color color;
  final String symbolAsset;
  final bool kingdomAttackUnlocked;
  final WinConditionType activeWinCondition;
  final CrossAxisAlignment alignment;

  const ScorePanel({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    required this.symbolAsset,
    required this.kingdomAttackUnlocked,
    required this.activeWinCondition,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (alignment == CrossAxisAlignment.end) ...[
          _buildTextContent(context),
          const SizedBox(width: 12),
          _buildSymbol(),
        ] else ...[
          _buildSymbol(),
          const SizedBox(width: 12),
          _buildTextContent(context),
        ],
      ],
    );
  }

  Widget _buildSymbol() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: Image.asset(
        symbolAsset,
        width: 32,
        height: 32,
        color: color,
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 13,
          ),
        ),
        Text(
          "POINTS: $points",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (kingdomAttackUnlocked) ...[
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              "KINGDOM ATTACK!", 
              style: TextStyle(
                color: Colors.yellow, 
                fontSize: 10, 
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                shadows: [Shadow(color: Colors.yellowAccent, blurRadius: 4)]
              )
            ),
          ),
        ],
      ],
    );
  }
}
