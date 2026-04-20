/// Represents the types of win conditions in order of priority.
enum WinConditionType {
  /// Primary win condition: Top-Left to Top-Right blockade around the palace.
  uShape,

  /// Secondary win condition: Left-Edge to Right-Edge parallel blockade.
  parallel,

  /// Final win condition: Blockade connecting any two anchors via the attacker's own kingdom.
  kingdomAssisted,
}
