import '../../core/models/level_config.dart';
import '../models/battle_config.dart';

final Map<String, BattleConfig> kBattleConfigs = {
  'snowy_village': const BattleConfig(
    kingdomId: 'snowy_village',
    levelConfig: LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 30,
      aiKingdomAttackThreshold: 30,
    ),
    aiDepth: 2,
  ),
  'blue_dome_town': const BattleConfig(
    kingdomId: 'blue_dome_town',
    levelConfig: LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 50,
      aiKingdomAttackThreshold: 50,
    ),
    aiDepth: 2,
  ),
  'coastal_castle': const BattleConfig(
    kingdomId: 'coastal_castle',
    levelConfig: LevelConfig(
      boardWidth: 17,
      boardHeight: 17,
      playerKingdomAttackThreshold: 60,
      aiKingdomAttackThreshold: 60,
    ),
    aiDepth: 3,
  ),
  'pyramid_area': const BattleConfig(
    kingdomId: 'pyramid_area',
    levelConfig: LevelConfig(
      boardWidth: 17,
      boardHeight: 17,
      playerKingdomAttackThreshold: 60,
      aiKingdomAttackThreshold: 60,
    ),
    aiDepth: 3,
  ),
  'desert_settlement': const BattleConfig(
    kingdomId: 'desert_settlement',
    levelConfig: LevelConfig(
      boardWidth: 19,
      boardHeight: 19,
      playerKingdomAttackThreshold: 70,
      aiKingdomAttackThreshold: 70,
    ),
    aiDepth: 3,
  ),
  'large_fort': const BattleConfig(
    kingdomId: 'large_fort',
    levelConfig: LevelConfig(
      boardWidth: 19,
      boardHeight: 19,
      playerKingdomAttackThreshold: 70,
      aiKingdomAttackThreshold: 70,
    ),
    aiDepth: 4,
  ),
  'oriental_pagoda': const BattleConfig(
    kingdomId: 'oriental_pagoda',
    levelConfig: LevelConfig(
      boardWidth: 21,
      boardHeight: 21,
      playerKingdomAttackThreshold: 80,
      aiKingdomAttackThreshold: 80,
    ),
    aiDepth: 4,
  ),
  'southern_city': const BattleConfig(
    kingdomId: 'southern_city',
    levelConfig: LevelConfig(
      boardWidth: 25,
      boardHeight: 25,
      playerKingdomAttackThreshold: 100,
      aiKingdomAttackThreshold: 100,
    ),
    aiDepth: 5,
  ),
};
