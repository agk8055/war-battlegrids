import '../../core/enums/turn.dart';
import '../game_simulation.dart';

enum AIStrategyType {
  basic,        // Kingdom 1: Only basic capture threats
  doubleThreat, // Kingdom 2: Creates double threats
  defensive,    // Kingdom 3: Plays defensively, never leaves pieces hanging
  aggressive,   // Kingdom 4: Zone dominance
  forkExpert,   // Kingdom 5: Fork strategy + sigil focus
  master        // Final Kingdom: Everything sharp
}

class AIStrategy {
  final AIStrategyType type;
  
  // Weights for Evaluator
  final int captureWeight;
  final int palaceAttackWeight;
  final int palaceDefendWeight;
  final int connectivityWeight;
  final int zoneControlWeight;
  final int sigilWeight;
  
  // Behavioral Flags
  final bool prioritizeDoubleThreats;
  final bool avoidHangingPieces;
  final bool focusOnForks;
  
  // Search Depth - We still use depth, but it's no longer the ONLY scale.
  final int searchDepth;

  const AIStrategy({
    required this.type,
    this.captureWeight = 100,
    this.palaceAttackWeight = 50,
    this.palaceDefendWeight = 10,
    this.connectivityWeight = 40,
    this.zoneControlWeight = 0,
    this.sigilWeight = 150,
    this.prioritizeDoubleThreats = false,
    this.avoidHangingPieces = false,
    this.focusOnForks = false,
    required this.searchDepth,
  });

  factory AIStrategy.fromType(AIStrategyType type) {
    switch (type) {
      case AIStrategyType.basic:
        return const AIStrategy(
          type: AIStrategyType.basic,
          captureWeight: 100,
          palaceAttackWeight: 10,
          palaceDefendWeight: 5,
          connectivityWeight: 0,
          sigilWeight: 50,
          searchDepth: 2,
        );
      case AIStrategyType.doubleThreat:
        return const AIStrategy(
          type: AIStrategyType.doubleThreat,
          captureWeight: 150, // Increased to prioritize immediate gains
          palaceAttackWeight: 30,
          palaceDefendWeight: 15,
          connectivityWeight: 20,
          prioritizeDoubleThreats: true,
          searchDepth: 2,
        );
      case AIStrategyType.defensive:
        return const AIStrategy(
          type: AIStrategyType.defensive,
          captureWeight: 120,
          palaceAttackWeight: 40,
          palaceDefendWeight: 120, // Heavily prioritized defense
          connectivityWeight: 50,
          avoidHangingPieces: true,
          searchDepth: 2,
        );
      case AIStrategyType.aggressive:
        return const AIStrategy(
          type: AIStrategyType.aggressive,
          captureWeight: 130,
          palaceAttackWeight: 150, // High offensive pressure
          palaceDefendWeight: 30,
          connectivityWeight: 70,
          zoneControlWeight: 100,
          searchDepth: 2,
        );
      case AIStrategyType.forkExpert:
        return const AIStrategy(
          type: AIStrategyType.forkExpert,
          captureWeight: 140,
          palaceAttackWeight: 80,
          palaceDefendWeight: 50,
          connectivityWeight: 60,
          focusOnForks: true,
          sigilWeight: 400, // Very high focus on win threats
          searchDepth: 2,
        );
      case AIStrategyType.master:
        return const AIStrategy(
          type: AIStrategyType.master,
          captureWeight: 200,
          palaceAttackWeight: 200,
          palaceDefendWeight: 150,
          connectivityWeight: 100,
          zoneControlWeight: 150,
          sigilWeight: 500,
          prioritizeDoubleThreats: true,
          avoidHangingPieces: true,
          focusOnForks: true,
          searchDepth: 2,
        );
    }
  }

  String get displayName {
    switch (type) {
      case AIStrategyType.basic: return "Novice";
      case AIStrategyType.doubleThreat: return "Tactician";
      case AIStrategyType.defensive: return "Guardian";
      case AIStrategyType.aggressive: return "Conqueror";
      case AIStrategyType.forkExpert: return "Grandmaster";
      case AIStrategyType.master: return "Legendary";
    }
  }
}
