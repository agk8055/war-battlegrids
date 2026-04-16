

/// Utility methods for board coordinate math and adjacency.
class BoardUtils {
  /// Returns a list of valid (x, y) coordinates adjacent to the given (x, y)
  /// considering the board boundaries.
  static List<(int, int)> getAdjacentCoordinates(int x, int y, int width, int height) {
    final List<(int, int)> neighbors = [];
    
    // Up
    if (y > 0) neighbors.add((x, y - 1));
    // Down
    if (y < height - 1) neighbors.add((x, y + 1));
    // Left
    if (x > 0) neighbors.add((x - 1, y));
    // Right
    if (x < width - 1) neighbors.add((x + 1, y));

    return neighbors;
  }
}
