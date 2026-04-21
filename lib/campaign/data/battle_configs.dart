import '../../core/models/level_config.dart';
import '../models/battle_config.dart';
import '../../simulation/ai/ai_strategy.dart';

final Map<String, BattleConfig> kBattleConfigs = {
  'snowy_village': BattleConfig(
    kingdomId: 'snowy_village',
    mapPath: '15x15_northern_forest_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 10,
      aiKingdomAttackThreshold: 10,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.basic),
  ),
  'blue_dome_town': BattleConfig(
    kingdomId: 'blue_dome_town',
    mapPath: '15x15_northern_forest_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 20,
      aiKingdomAttackThreshold: 20,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.doubleThreat),
  ),
  'coastal_castle': BattleConfig(
    kingdomId: 'coastal_castle',
    mapPath: '15x15_northern_forest_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 20,
      aiKingdomAttackThreshold: 10,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.defensive),
  ),
  'pyramid_area': BattleConfig(
    kingdomId: 'pyramid_area',
    mapPath: '15x15_northern_forest_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 60,
      aiKingdomAttackThreshold: 60,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.aggressive),
  ),
  'desert_settlement': BattleConfig(
    kingdomId: 'desert_settlement',
    mapPath: '15x15_northern_forest_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 70,
      aiKingdomAttackThreshold: 70,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.forkExpert),
  ),
  'large_fort': BattleConfig(
    kingdomId: 'large_fort',
    mapPath: '15x15_northern_forest_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 70,
      aiKingdomAttackThreshold: 70,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
  ),
  'oriental_pagoda': BattleConfig(
    kingdomId: 'oriental_pagoda',
    mapPath: '25x25_map.tmx',
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
    mapPath: '25x25_map.tmx',
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 100,
      aiKingdomAttackThreshold: 100,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
  ),
};
