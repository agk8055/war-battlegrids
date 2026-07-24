import '../../core/constants/app_assets.dart';
import '../../core/models/level_config.dart';
import '../models/battle_config.dart';
import '../../simulation/ai/ai_strategy.dart';

final Map<String, BattleConfig> kBattleConfigs = {
  'northern_village': BattleConfig(
    kingdomId: 'northern_village',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 10,
      aiKingdomAttackThreshold: 10,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.basic),
    insight: "The frozen ground makes movement predictable. Use this to your advantage.",
  ),
  'blue_dome_town': BattleConfig(
    kingdomId: 'blue_dome_town',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 20,
      aiKingdomAttackThreshold: 20,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.doubleThreat),
    insight: "Watch for flanking maneuvers from the scholar-guards.",
  ),
  'coastal_castle': BattleConfig(
    kingdomId: 'coastal_castle',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 20,
      aiKingdomAttackThreshold: 20,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.defensive),
    insight: "Sea Watch's defenses are toughest from the front. Seek another way.",
  ),
  'pyramid_area': BattleConfig(
    kingdomId: 'pyramid_area',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 30,
      aiKingdomAttackThreshold: 30,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.aggressive),
    insight: "The Great Sphinx's layout favors high-stakes aggression.",
  ),
  'desert_settlement': BattleConfig(
    kingdomId: 'desert_settlement',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 30,
      aiKingdomAttackThreshold: 30,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.forkExpert),
    insight: "Oasis intersections are critical. Control the water to control the battle.",
  ),
  'large_fort': BattleConfig(
    kingdomId: 'large_fort',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 15,
      boardHeight: 15,
      playerKingdomAttackThreshold: 30,
      aiKingdomAttackThreshold: 30,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
    insight: "Iron Bastion's walls are legend. Only persistent pressure can break them.",
  ),
  'oriental_pagoda': BattleConfig(
    kingdomId: 'oriental_pagoda',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 80,
      aiKingdomAttackThreshold: 80,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
    insight: "The serene landscape hides complex paths. Every step must be measured.",
  ),
  'southern_city': BattleConfig(
    kingdomId: 'southern_city',
    mapPath: AppAssets.northernForestMap,
    levelConfig: const LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 100,
      aiKingdomAttackThreshold: 100,
    ),
    aiStrategy: AIStrategy.fromType(AIStrategyType.master),
    insight: "The Capital's sprawling layout rewards those who think several steps ahead.",
  ),
};
