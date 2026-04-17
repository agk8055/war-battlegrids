import '../constants/board_constants.dart';
import '../constants/game_constants.dart';

class LevelConfig {
  final int boardWidth;
  final int boardHeight;
  final int playerKingdomAttackThreshold;
  final int aiKingdomAttackThreshold;

  const LevelConfig({
    required this.boardWidth,
    required this.boardHeight,
    required this.playerKingdomAttackThreshold,
    required this.aiKingdomAttackThreshold,
  });

  factory LevelConfig.standard() {
    return const LevelConfig(
      boardWidth: kDefaultBoardWidth,
      boardHeight: kDefaultBoardHeight,
      playerKingdomAttackThreshold: kPlayerKingdomAttackThreshold,
      aiKingdomAttackThreshold: kAIKingdomAttackThreshold,
    );
  }
}
