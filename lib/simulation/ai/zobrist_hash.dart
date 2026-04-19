import 'dart:math';
import '../../core/enums/cell_state.dart';
import '../board.dart';

class ZobristHash {
  static final Random _random = Random(42); // Fixed seed for reproducibility
  static late List<List<int>> _table;
  static late int _turnPlayer;
  static late int _turnAI;
  static bool _initialized = false;

  static void initialize(int width, int height) {
    if (_initialized) return;

    // 361 cells * 9 possible states
    _table = List.generate(
      width * height,
      (_) => List.generate(CellState.values.length, (_) => _random.nextInt(1 << 31)),
    );

    _turnPlayer = _random.nextInt(1 << 31);
    _turnAI = _random.nextInt(1 << 31);

    _initialized = true;
  }

  static int computeHash(Board board, bool isAITurn) {
    int h = 0;
    for (int y = 0; y < board.height; y++) {
      for (int x = 0; x < board.width; x++) {
        final state = board.getCell(x, y);
        if (state != CellState.empty) {
          h ^= _table[y * board.width + x][state.index];
        }
      }
    }
    h ^= isAITurn ? _turnAI : _turnPlayer;
    return h;
  }
}
