import '../../core/models/level_config.dart';

class BattleConfig {
  final String kingdomId;
  final LevelConfig levelConfig;
  final int aiDepth;

  const BattleConfig({
    required this.kingdomId,
    required this.levelConfig,
    required this.aiDepth,
  });
}
