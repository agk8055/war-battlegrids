/// Represents the types of win conditions in strict order of priority.
enum WinConditionType {
  /// Tier 1: Full U-shape encirclement connecting both flanks (top-left to top-right) around the palace.
  fullUShape,

  /// Tier 2: Half U-shape encirclement connecting an edge to the opposite flank (active only when full U is blocked).
  halfUShape,

  /// Tier 3: Left-Edge to Right-Edge parallel blockade (active only when half U is also blocked).
  parallel,

  /// Tier 4: Final win condition connecting anchors via the attacker's own kingdom.
  kingdomAssisted,
}

