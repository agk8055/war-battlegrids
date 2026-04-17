/// Represents the state of a single cell on the board grid.
enum CellState {
  /// An empty tile where any unit can be placed.
  empty,

  /// Occupied by a Player unit.
  player,

  /// Occupied by an AI unit.
  ai,

  /// A designated zone tile belonging to the Player (Kingdom Zone).
  playerZone,

  /// A designated zone tile belonging to the AI (Kingdom Zone).
  aiZone,

  /// The crucial Sigil belonging to the Player.
  playerSigil,

  /// The crucial Sigil belonging to the AI.
  aiSigil,

  /// A tile where a unit was captured, rendering it permanently unplayable.
  capturedGrid,

  /// An obstacle tile (tree, stone, etc.) that is not deployable.
  obstacle,
}
