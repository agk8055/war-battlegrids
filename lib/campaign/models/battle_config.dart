import '../../core/models/level_config.dart';
import '../../simulation/ai/ai_strategy.dart';

class BattleConfig {
  final String kingdomId;
  final String mapPath;
  final LevelConfig levelConfig;
  final AIStrategy aiStrategy;
  final String? insight;

  const BattleConfig({
    required this.kingdomId,
    required this.mapPath,
    required this.levelConfig,
    required this.aiStrategy,
    this.insight,
  });
}
