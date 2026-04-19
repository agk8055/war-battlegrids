import '../../core/models/level_config.dart';
import '../../simulation/ai/ai_strategy.dart';

class BattleConfig {
  final String kingdomId;
  final LevelConfig levelConfig;
  final AIStrategy aiStrategy;

  const BattleConfig({
    required this.kingdomId,
    required this.levelConfig,
    required this.aiStrategy,
  });
}
