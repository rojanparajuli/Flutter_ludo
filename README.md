# flutter_ludo

[![pub package](https://img.shields.io/pub/v/flutter_ludo.svg)](https://pub.dev/packages/flutter_ludo)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A complete Ludo game for Flutter: a rules engine, an animated board and dice,
bots with three difficulty levels, 2v2 teams, configurable rules, and
save/restore. Drop in one widget for a full game, or drive the engine
yourself and build your own UI.

![Screenshot](https://raw.githubusercontent.com/rojanparajuli/Flutter_ludo/master/assets/ss.jpg)

## Features

- **Play against bots.** Any seat can be a bot. There are three built-in
  difficulties (easy, medium, hard), and you can plug in your own strategy.
  Seats can switch between human and bot mid-game.
- **2–4 players**, plus a **2v2 teams mode**.
- **Configurable rules.** You choose which dice values start a piece and
  which grant another roll. Optional extras: a bonus roll on capture or on
  finishing a piece, and "three 6s in a row forfeits the turn". A
  `LudoDiceRules.modern()` preset turns these on.
- **Ready-made UI.** `LudoSetup` is a full game with a setup screen.
  `LudoGame` is the game screen. `LudoBoard` and `LudoDice` can also be used
  on their own.
- **Step-by-step piece animation**, dice shake, a highlight on the last
  moved piece, and stacked pieces fanned out so each one can be seen.
- **Light and dark themes** through `LudoTheme`.
- **Save and resume.** `LudoGameState` serializes to JSON.
- **Pause and resume**, **move hints** (`suggestMove()`), and **8 event
  callbacks**.
- **A pure, stateless engine** (`LudoEngine`) that you can use for
  servers, simulations, or AI training.
- Screen-reader labels on the dice, pieces, and setup controls.
- Well tested: rules, engine, controller, bots (full simulated games in
  every configuration), and widgets.

## Installation

```sh
flutter pub add flutter_ludo
```

## Quick start

A complete game with a setup screen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

void main() => runApp(const MaterialApp(home: LudoSetup()));
```

To skip the setup screen and play against three bots:

```dart
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final controller = LudoController(
    players: const [
      LudoPlayer(name: 'You', color: Colors.red),
      LudoPlayer(name: 'Bot 1', color: Colors.blue),
      LudoPlayer(name: 'Bot 2', color: Colors.green),
      LudoPlayer(name: 'Bot 3', color: Colors.amber),
    ],
    botPlayers: {1, 2, 3},
    botDifficulty: LudoBotDifficulty.hard,
    onGameFinished: (winners) => debugPrint('Ranking: $winners'),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: LudoGame(controller: controller));
}
```

The widgets listen to the controller, so there is nothing to wire up.
The controller is yours: create it, then call `dispose()` when you're done.

## Bots

```dart
LudoController(
  players: players,
  botPlayers: {1, 3},                         // which seats are bots
  botDifficulty: LudoBotDifficulty.medium,    // easy | medium | hard
  botThinkDuration: Duration(milliseconds: 500),
);
```

| Difficulty | Plays |
|---|---|
| `easy` | A random legal move. |
| `medium` | Heuristics: capture, leave home, reach safe cells and the home stretch, push the lead piece, avoid landing within 6 cells of an opponent. |
| `hard` | Medium's heuristics, plus moving threatened pieces to safety and preferring to capture pieces that have travelled further. |

In 4,000-game simulations, `hard` beats `medium` about 52% of the time, and
both beat `easy` about 85–89% of the time. Ludo is mostly luck, so the gaps
between skill levels stay small.

At runtime you can:

```dart
controller.setBot(0, true);                          // bot takes over seat 0
controller.botDifficulty = LudoBotDifficulty.hard;   // change skill level
controller.pause();                                  // stop bots, block input
controller.resume();
```

### Custom bot strategy

```dart
class GreedyBot extends LudoBotStrategy {
  const GreedyBot();

  @override
  LudoLegalMove chooseMove(LudoGameState state) =>
      state.legalMoves.reduce((a, b) => a.toPosition >= b.toPosition ? a : b);
}

LudoController(players: players, botPlayers: {1}, botStrategy: const GreedyBot());
```

If a strategy throws or returns an illegal move, the controller reports the
error through `FlutterError.onError` and plays the first legal move, so the
game never stalls.

## Rules

```dart
const LudoDiceRules(
  startAllowedValues: [6],     // values that bring a piece out of home
  extraTurnValues: [6],        // values that grant another roll
  extraTurnOnCapture: false,   // bonus roll after capturing
  extraTurnOnFinish: false,    // bonus roll after a piece reaches the center
  forfeitStreak: null,         // e.g. 3: the third 6 in a row loses the turn
)

const LudoDiceRules.modern()   // 6 to start, bonus rolls on 6/capture/finish,
                               // three 6s forfeit
```

### Rules reference

- **Players:** 2–4. In teams mode there are exactly 4: seats 0+3 play
  against seats 1+2.
- **Board:** standard 15×15 board with a 52-cell shared path. Each player
  has a 5-cell home stretch. There are 8 safe cells: each start cell plus
  one star per arm.
- **Starting:** a piece leaves home only on a value in `startAllowedValues`.
- **Capturing:** landing exactly on an opponent's piece sends it home,
  unless the cell is safe. A piece can't land on a safe cell that an
  opponent occupies. Teammates never capture each other.
- **Finishing:** a piece needs an exact roll to reach the center. Moves
  that would overshoot aren't offered.
- **Turns:** if a roll has no legal move, the turn passes automatically. A
  player who just finished all 4 pieces never gets a bonus roll.
- **Game end:** the game ends when all but one player have finished, and
  the last player is placed last. In teams mode it ends as soon as both
  players of one team have finished.

## Events

```dart
LudoController(
  players: players,
  onDiceRolled: (value) {},
  onPieceMoved: (piece, from, to) {},
  onPieceCaptured: (captured, by) {},
  onTurnChanged: (playerIndex) {},
  onTurnForfeited: (playerIndex, streak) {},
  onPlayerWon: (playerIndex, place) {},      // place is 1-based
  onTeamWon: (team) {},
  onGameFinished: (winnersInOrder) {},
)
```

## Save and resume

```dart
final json = jsonEncode(controller.state.toJson());   // store anywhere
// ...later
controller.restore(LudoGameState.fromJson(jsonDecode(json)));
```

## Theming

```dart
LudoGame(controller: controller, theme: LudoTheme.dark)

LudoSetup(theme: LudoTheme.defaultTheme.copyWith(
  safeCellColor: Colors.amber.shade100,
  lastMovedColor: Colors.purple,
))
```

## Building your own UI

Use `LudoBoard` and `LudoDice` on their own, or read `controller.state`
directly:

```dart
Column(children: [
  Expanded(child: LudoBoard(controller: controller)),
  LudoDice(controller: controller),
])
```

```dart
if (controller.canRoll) controller.rollDice();
final moves = controller.state.legalMoves;
if (controller.canSelectPiece) await controller.selectPiece(moves.first.pieceId);
controller.suggestMove();   // the hard bot's pick, handy for hints
```

`LudoGameState` is immutable. It exposes `players`, `pieces`,
`currentPlayerIndex`, `phase`, `diceValue`, `lastRoll`, `legalMoves`,
`winners`, `teams`, and helpers like `progressOf(player)`.

For servers or simulations, use the engine directly:

```dart
const engine = LudoEngine(LudoDiceRules());
var state = LudoGameState.initial(players);
final roll = engine.roll(state, 6);
state = engine.move(roll.state, roll.state.legalMoves.first.pieceId).state;
```

## Testing your app

To make games deterministic, script the dice and turn off delays:

```dart
final rolls = [6, 4, 3];
var i = 0;
final controller = LudoController(
  players: players,
  diceRoller: () => rolls[i++],
  stepAnimationDuration: Duration.zero,   // moves commit immediately
  autoMoveSingleChoice: false,
);
```

## Migrating from 0.1.x

- Bots are now part of `LudoController`. Replace
  `LudoBotController(botPlayerIndices: {...}, thinkDuration: d)` with
  `LudoController(botPlayers: {...}, botThinkDuration: d)`, and
  `LudoGame(botController: c)` with `LudoGame(controller: c)`. The old names
  still work but are deprecated.
- `LudoGame`, `LudoBoard`, and `LudoDice` now rebuild when the controller
  changes. You no longer need your own `ListenableBuilder`.
- `LudoTeam` and `kDefaultTeams` are now exported from
  `package:flutter_ludo/flutter_ludo.dart`.
- `selectPiece` has always returned a `Future`. Await it, or set
  `stepAnimationDuration: Duration.zero`, before reading the new state.
- The `enableAudio` and `showAudioToggle` flags have had no effect since
  0.1.0 and are now deprecated.

## Example

The [example app](example/lib/main.dart) shows the setup screen, the dark
theme, and a game driven from code with hints, pause, and save/restore:

```sh
cd example && flutter run
```

## License

MIT. See [LICENSE](LICENSE).
