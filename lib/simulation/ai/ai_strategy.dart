import '../../core/enums/turn.dart';
import '../game_simulation.dart';

enum AIStrategyType {
  basic,        // Novice (Kingdom 1): Basic capture threats and 1-move defense
  doubleThreat, // Tactician (Kingdom 2): Creates double threats and dual-flank attacks
  defensive,    // Guardian (Kingdom 3): High anti-blockade anticipation, palace flank protection
  aggressive,   // Conqueror (Kingdom 4): Glory capture race and deep palace breach assault
  forkExpert,   // Grandmaster (Kingdom 5): Multi-tier win threats and bottleneck traps
  master        // Legendary (Kingdoms 6-8): Master of all stages, multi-step blockade prevention
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
  final int flankDefenseWeight;
  final int chainCuttingWeight;
  final int gloryHuntWeight;
  
  // Behavioral Flags
  final bool prioritizeDoubleThreats;
  final bool avoidHangingPieces;
  final bool focusOnForks;
  final bool anticipateBlockades;
  
  // Rule Engine Options
  final bool useRuleWinInstantly;
  final bool useRuleImmediateCapture;
  final bool useRuleBlocking;
  final bool useRuleDoubleThreat;
  final bool useRuleSigil;
  
  // Search Depth
  final int searchDepth;

  const AIStrategy({
    required this.type,
    this.captureWeight = 100,
    this.palaceAttackWeight = 50,
    this.palaceDefendWeight = 50,
    this.connectivityWeight = 40,
    this.zoneControlWeight = 0,
    this.sigilWeight = 150,
    this.flankDefenseWeight = 60,
    this.chainCuttingWeight = 60,
    this.gloryHuntWeight = 120,
    this.prioritizeDoubleThreats = false,
    this.avoidHangingPieces = false,
    this.focusOnForks = false,
    this.anticipateBlockades = false,
    this.useRuleWinInstantly = true,
    this.useRuleImmediateCapture = true,
    this.useRuleBlocking = true,
    this.useRuleDoubleThreat = true,
    this.useRuleSigil = true,
    required this.searchDepth,
  });

  factory AIStrategy.fromType(AIStrategyType type) {
    switch (type) {
      case AIStrategyType.basic:
        return const AIStrategy(
          type: AIStrategyType.basic,
          captureWeight: 100,
          palaceAttackWeight: 10,
          palaceDefendWeight: 20,
          connectivityWeight: 10,
          sigilWeight: 50,
          flankDefenseWeight: 30,
          chainCuttingWeight: 30,
          gloryHuntWeight: 100,
          anticipateBlockades: false,
          searchDepth: 2,
        );
      case AIStrategyType.doubleThreat:
        return const AIStrategy(
          type: AIStrategyType.doubleThreat,
          captureWeight: 150,
          palaceAttackWeight: 40,
          palaceDefendWeight: 30,
          connectivityWeight: 25,
          flankDefenseWeight: 40,
          chainCuttingWeight: 40,
          gloryHuntWeight: 140,
          prioritizeDoubleThreats: true,
          anticipateBlockades: false,
          searchDepth: 2,
        );
      case AIStrategyType.defensive:
        return const AIStrategy(
          type: AIStrategyType.defensive,
          captureWeight: 120,
          palaceAttackWeight: 40,
          palaceDefendWeight: 160,
          connectivityWeight: 50,
          sigilWeight: 200,
          flankDefenseWeight: 180,
          chainCuttingWeight: 150,
          gloryHuntWeight: 120,
          avoidHangingPieces: true,
          anticipateBlockades: true,
          searchDepth: 2,
        );
      case AIStrategyType.aggressive:
        return const AIStrategy(
          type: AIStrategyType.aggressive,
          captureWeight: 160,
          palaceAttackWeight: 180,
          palaceDefendWeight: 40,
          connectivityWeight: 70,
          zoneControlWeight: 120,
          sigilWeight: 250,
          flankDefenseWeight: 50,
          chainCuttingWeight: 50,
          gloryHuntWeight: 200,
          anticipateBlockades: false,
          searchDepth: 2,
        );
      case AIStrategyType.forkExpert:
        return const AIStrategy(
          type: AIStrategyType.forkExpert,
          captureWeight: 140,
          palaceAttackWeight: 90,
          palaceDefendWeight: 80,
          connectivityWeight: 60,
          sigilWeight: 400,
          flankDefenseWeight: 100,
          chainCuttingWeight: 100,
          gloryHuntWeight: 150,
          focusOnForks: true,
          anticipateBlockades: true,
          searchDepth: 2,
        );
      case AIStrategyType.master:
        return const AIStrategy(
          type: AIStrategyType.master,
          captureWeight: 220,
          palaceAttackWeight: 220,
          palaceDefendWeight: 200,
          connectivityWeight: 100,
          zoneControlWeight: 150,
          sigilWeight: 500,
          flankDefenseWeight: 220,
          chainCuttingWeight: 200,
          gloryHuntWeight: 220,
          prioritizeDoubleThreats: true,
          avoidHangingPieces: true,
          focusOnForks: true,
          anticipateBlockades: true,
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
