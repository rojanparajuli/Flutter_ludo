// Fixed geometry of the standard, 4-player Ludo board, expressed as a 15x15
// grid of `[row, col]` cells.
//
// Per the package specification this geometry is intentionally NOT
// configurable: 4 players, fixed safe zones, fixed capture rules, and fixed
// board layout. Only visual styling (see `themes/ludo_theme.dart`) and dice
// behaviour (see `models/ludo_dice_rules.dart`) are configurable.
//
// Coordinate system: `[row, col]`, both zero-indexed, `0 <= row, col <= 14`.

/// Width/height of the board grid, in cells.
const int kBoardGridSize = 15;

/// The 52 cells of the shared outer path, listed in clockwise travel order
/// as `[row, col]` pairs. Index 0 is player 0's start cell; index 13 is
/// player 1's; 26 is player 2's; 39 is player 3's (see [kStartIndices]).
const List<List<int>> kPathCells = [
  [6, 1], [6, 2], [6, 3], [6, 4], [6, 5], // 0-4
  [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6], // 5-10
  [0, 7], // 11
  [0, 8], // 12
  [1, 8], [2, 8], [3, 8], [4, 8], [5, 8], // 13-17
  [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14], // 18-23
  [7, 14], // 24
  [8, 14], // 25
  [8, 13], [8, 12], [8, 11], [8, 10], [8, 9], // 26-30
  [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8], // 31-36
  [14, 7], // 37
  [14, 6], // 38
  [13, 6], [12, 6], [11, 6], [10, 6], [9, 6], // 39-43
  [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0], // 44-49
  [7, 0], // 50
  [6, 0], // 51
];

/// Index into [kPathCells] where each of the 4 players enters the board.
const List<int> kStartIndices = [0, 13, 26, 39];

/// Indices into [kPathCells] that are designated "star"/safe cells. A piece
/// sitting on one of these cells (including any player's start cell) can
/// never be captured.
const Set<int> kSafeIndices = {0, 8, 13, 21, 26, 34, 39, 47};

/// Each player's 5-cell colored home stretch, ordered from its entrance
/// (reached right after the 51st shared-path cell) to the cell adjacent to
/// the center. Indexed by player (0-3), in the same order as
/// [kStartIndices].
const List<List<List<int>>> kHomeStretchCells = [
  [
    [7, 1],
    [7, 2],
    [7, 3],
    [7, 4],
    [7, 5],
  ],
  [
    [1, 7],
    [2, 7],
    [3, 7],
    [4, 7],
    [5, 7],
  ],
  [
    [7, 13],
    [7, 12],
    [7, 11],
    [7, 10],
    [7, 9],
  ],
  [
    [13, 7],
    [12, 7],
    [11, 7],
    [10, 7],
    [9, 7],
  ],
];

/// The single center cell every piece is ultimately heading toward.
const List<int> kCenterCell = [7, 7];

/// Top-left `[row, col]` origin of each player's 6x6 home base quadrant, in
/// the same player-index order as [kStartIndices].
const List<List<int>> kHomeBaseOrigins = [
  [0, 0], // player 0: top-left
  [0, 9], // player 1: top-right
  [9, 9], // player 2: bottom-right
  [9, 0], // player 3: bottom-left
];

/// Local `[row, col]` offsets (within a 6x6 home base) where a player's 4
/// waiting pieces sit before entering the board.
const List<List<int>> kHomeYardSlots = [
  [1, 1],
  [1, 4],
  [4, 1],
  [4, 4],
];

/// Resolves a piece's relative track position (must be in `0..50`, i.e. on
/// the shared path — see `LudoPiece.isOnSharedPath`) for [playerIndex] to an
/// absolute index into [kPathCells].
int globalCellOf(int playerIndex, int trackPosition) {
  return (kStartIndices[playerIndex] + trackPosition) % kPathCells.length;
}

/// Whether the given absolute index into [kPathCells] is a safe cell.
bool isSafeCellIndex(int globalIndex) => kSafeIndices.contains(globalIndex);

/// Resolves any non-home track position to a `[row, col]` grid cell, for
/// rendering.
///
/// * `trackPosition` in `0..50` -> a cell on the shared path.
/// * `trackPosition` in `51..55` -> a cell in the player's home stretch.
/// * `trackPosition` of `56` (finished) -> [kCenterCell].
///
/// Returns `null` for a piece still at home (`trackPosition < 0`) — callers
/// should use [kHomeBaseOrigins] / [kHomeYardSlots] for those instead.
List<int>? gridCellFor(int playerIndex, int trackPosition) {
  if (trackPosition < 0) return null;
  if (trackPosition >= 56) return kCenterCell;
  if (trackPosition < 51) {
    return kPathCells[globalCellOf(playerIndex, trackPosition)];
  }
  return kHomeStretchCells[playerIndex][trackPosition - 51];
}