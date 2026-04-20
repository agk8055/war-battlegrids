import 'dart:math';
import '../../core/enums/cell_state.dart';

class ZobristHash {
  static final Random _random = Random(42); // Fixed seed for reproducibility
  static List<List<int>> _table = [];
  static int _turnPlayer = 0;
  static int _turnAI = 0;
  static int _initializedWidth = 0;
  static int _initializedHeight = 0;

  static bool get isInitialized => _initializedWidth > 0 && _initializedHeight > 0;

  /// Initializes the Zobrist table for the given dimensions.
  /// Returns true if the table was (re)initialized, false if skipped.
  static bool initialize(int width, int height) {
    if (_initializedWidth == width && _initializedHeight == height) return false;

    // 64-bit random values
    _table = List.generate(
      width * height,
      (_) => List.generate(CellState.values.length, (_) => 
        _random.nextInt(0x7FFFFFFF) ^ (_random.nextInt(0x7FFFFFFF) << 32)),
    );

    _turnPlayer = _random.nextInt(0x7FFFFFFF) ^ (_random.nextInt(0x7FFFFFFF) << 32);
    _turnAI = _random.nextInt(0x7FFFFFFF) ^ (_random.nextInt(0x7FFFFFFF) << 32);

    _initializedWidth = width;
    _initializedHeight = height;
    return true;
  }

  static int getTableValue(int x, int y, int width, int stateIndex) {
    return _table[y * width + x][stateIndex];
  }

  static int getTurnHash(bool isAITurn) => isAITurn ? _turnAI : _turnPlayer;

  /// Returns the final hash by XORing the board's current incremental hash with the turn value.
  static int computeHash(int boardHash, bool isAITurn) {
    return boardHash ^ (isAITurn ? _turnAI : _turnPlayer);
  }
}
