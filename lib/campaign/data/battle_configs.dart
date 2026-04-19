import '../../core/models/level_config.dart';
import '../models/battle_config.dart';
import '../../simulation/ai/ai_strategy.dart';

final Map<String, BattleConfig> kBattleConfigs = {
  'snowy_village': BattleConfig(
    kingdomId: 'snowy_village',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 30,
      aiKingdomAttackThreshold: 30,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.basic),
  ),
  'blue_dome_town': BattleConfig(
    kingdomId: 'blue_dome_town',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 50,
      aiKingdomAttackThreshold: 50,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.doubleThreat),
  ),
  'coastal_castle': BattleConfig(
    kingdomId: 'coastal_castle',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 60,
      aiKingdomAttackThreshold: 60,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.defensive),
  ),
  'pyramid_area': BattleConfig(
    kingdomId: 'pyramid_area',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 60,
      aiKingdomAttackThreshold: 60,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.aggressive),
  ),
  'desert_settlement': BattleConfig(
    kingdomId: 'desert_settlement',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 70,
      aiKingdomAttackThreshold: 70,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.forkExpert),
  ),
  'large_fort': BattleConfig(
    kingdomId: 'large_fort',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 70,
      aiKingdomAttackThreshold: 70,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
  ),
  'oriental_pagoda': BattleConfig(
    kingdomId: 'oriental_pagoda',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 80,
      aiKingdomAttackThreshold: 80,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
  ),
  'southern_city': BattleConfig(
    kingdomId: 'southern_city',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 100,
      aiKingdomAttackThreshold: 100,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
  ),
};
