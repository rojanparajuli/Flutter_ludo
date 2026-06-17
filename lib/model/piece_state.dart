/// Lifecycle state of a single [LudoPiece], per the package specification.
enum LudoPieceState {
  /// Sitting in the player's home base; has not entered the board yet.
  home,

  /// On the shared path, on a cell that is not a designated safe cell. Can
  /// be captured by an opponent landing on the same cell.
  active,

  /// On a designated safe cell (a start cell, a star cell, or anywhere in
  /// the piece's own colored home stretch). Cannot be captured.
  safe,

  /// Has completed its journey and reached the final home cell.
  finished,
}