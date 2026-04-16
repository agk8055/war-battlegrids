/// Represents the broad phases of the game.
enum GamePhase {
  /// Players are alternating placing units on the board.
  placement,

  /// One of the players has unlocked their Kingdom Attack, dropping the enemy barrier.
  kingdomAttack,

  /// The game has concluded (either locally or due to campaign conditions).
  gameOver,
}
