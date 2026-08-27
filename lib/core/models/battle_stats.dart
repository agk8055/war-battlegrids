import '../enums/turn.dart';
import '../enums/win_condition_type.dart';

/// Tactical Accolades / Honor Badges awarded for combat feats.
enum TacticalBadgeType {
  grandStrategist,
  blitzkrieg,
  ironWall,
  masterEncirclement,
  siegeBreaker,
  flawlessDefense,
  comebackVictory,
}

class TacticalBadge {
  final TacticalBadgeType type;
  final String title;
  final String description;
  final String icon;

  const TacticalBadge({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Comprehensive match statistics recorded during a battle.
class BattleStats {
  final Duration duration;
  final DateTime startTime;
  final DateTime endTime;
  
  final int totalTurns;
  final int playerMoves;
  final int opponentMoves;

  final int playerScore;
  final int opponentScore;

  final int playerCapturedUnits;
  final int opponentCapturedUnits;

  final int playerCaptureEvents;
  final int opponentCaptureEvents;

  final int playerMaxCombo;
  final int opponentMaxCombo;

  final double playerTerritoryPercent;
  final double opponentTerritoryPercent;

  final WinConditionType? winConditionType;
  final Turn? winner;
  final bool isDraw;

  final bool playerSiegeBreached;
  final bool opponentSiegeBreached;

  final List<TacticalBadge> earnedBadges;

  const BattleStats({
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.totalTurns,
    required this.playerMoves,
    required this.opponentMoves,
    required this.playerScore,
    required this.opponentScore,
    required this.playerCapturedUnits,
    required this.opponentCapturedUnits,
    required this.playerCaptureEvents,
    required this.opponentCaptureEvents,
    required this.playerMaxCombo,
    required this.opponentMaxCombo,
    required this.playerTerritoryPercent,
    required this.opponentTerritoryPercent,
    this.winConditionType,
    this.winner,
    this.isDraw = false,
    this.playerSiegeBreached = false,
    this.opponentSiegeBreached = false,
    this.earnedBadges = const [],
  });

  String get formattedDuration {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get winConditionDescription {
    if (isDraw) return 'Battle ended in stalemate';
    switch (winConditionType) {
      case WinConditionType.uShape:
        return 'U-Shape Palace Encirclement';
      case WinConditionType.parallel:
        return 'Parallel Flank Blockade';
      case WinConditionType.kingdomAssisted:
        return 'Royal Siege Assisted Blockade';
      case null:
        return 'Total Strategic Domination';
    }
  }
}
