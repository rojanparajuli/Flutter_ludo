## 0.0.8
- Added 2–4 player support (previously fixed at 4 players).
- Added `LudoSetup` widget with an interactive player-count selection screen (2, 3, or 4 players) before game start.
- Redesigned all UI to flat 2D style — removed all shadows, gradients, and 3D effects from tokens, board, and dice.
- Tokens now render as flat filled circles with a white inner ring and centre dot (classic physical Ludo look).
- Dice face replaced with real pip-dot grid instead of a text number.
- Added step-by-step piece movement animation — pieces now travel through each cell individually instead of jumping to the destination.
- Added bounce animation on each step arrival for tactile feedback.
- Auto-moves the piece automatically when only one legal move exists after rolling.
- Fixed stacked piece selection in safe zones — current player's pieces always render on top and receive tap events correctly even when opponents share the same cell.
- Wired all audio events: dice roll, per-step move tick, capture, piece reaching home stretch, player win, and game over.
- Fixed `AudioService` to use one `AudioPlayer` per sound type so concurrent sounds no longer cancel each other.
- Added animated turn pill that cross-fades on turn change with active player colour.
- Added player avatar row with colour chips and place medals (🥇🥈🥉) for finished players.
- Added game-over overlay with winner podium and Play Again button.
- Empty board quadrants (in 2–3 player games) render in grey with no piece slots.
- Fixed `steps` compile error — movement step count now derived from `move.toPosition - move.fromPosition`.

## 0.0.7
- Added partition borders for home bases to clearly show individual piece starting positions.
- Added movement trail effect for visual feedback when pieces move.
- Added last moved piece highlighting with yellow glow indicator.
- Enhanced stack visualization with piece numbers and position indicators.
- Improved visual feedback for legal moves in stacks.
- Added theme support for home borders, partitions, and movement trails.
- Optimized piece rendering with animated transitions.
- Fixed `lastMovedPiece` state management in game controller.
- audio for the dice roll added.

## 0.0.6
- Fixed an opponent's piece on a safe cell blocking taps to a player's own piece stacked underneath it.
- Stacked pieces of the same color are now moved automatically instead of prompting the player to choose one.

## 0.0.5
- Prevents accidental selection of opponent pieces during a player's turn.

## 0.0.4
- Improved Stack Interaction for pieces

## 0.0.3

- Fixed an issue where pieces underneath a stack could not be tapped.

## 0.0.2

- Added example application.
- Improved package documentation.

## 0.0.1

- Initial release of Flutter Ludo.
- Supports 4-player Ludo gameplay.
- Includes Ludo board widget.
- Includes game controller and engine.
- Move validation rules.
- Capture rules.
- Win condition rules.
- Dice widget and game widgets.