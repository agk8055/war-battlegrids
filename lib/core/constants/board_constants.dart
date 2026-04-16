// Board dimensions and configuration constants.

/// Standard width of the grid.
const int kBoardWidth = 15;

/// Standard height of the grid.
const int kBoardHeight = 15;

// Coordinate boundaries for the AI Kingdom (Palace).
// 4x2 box centered at top
const int kAIPalaceStartY = 0;
const int kAIPalaceEndY = 1;
const int kAIPalaceStartX = (kBoardWidth ~/ 2) - 2;
const int kAIPalaceEndX = (kBoardWidth ~/ 2) + 1; 

// Coordinate boundaries for the Player Kingdom (Palace).
// 4x2 box centered at bottom
const int kPlayerPalaceStartY = kBoardHeight - 2;
const int kPlayerPalaceEndY = kBoardHeight - 1;
const int kPlayerPalaceStartX = (kBoardWidth ~/ 2) - 2;
const int kPlayerPalaceEndX = (kBoardWidth ~/ 2) + 1;

/// Example default coordinates for the sigils.
const (int, int) kDefaultPlayerSigilCoord = (6, 10);
const (int, int) kDefaultAISigilCoord = (6, 1);
