import '../controller/ludo_controller.dart';
import 'ludo_bot_strategy.dart';

/// Legacy bot controller, kept for source compatibility.
///
/// Bots are now built into [LudoController]:
///
/// ```dart
/// LudoController(players: players, botPlayers: {1, 2, 3});
/// ```
@Deprecated(
  'Use LudoController(botPlayers: ...) instead. '
  'LudoBotController will be removed in 1.0.0.',
)
class LudoBotController extends LudoController {
  LudoBotController({
    required super.players,
    required Set<int> botPlayerIndices,
    super.diceRules,
    super.diceRoller,
    bool enableAudio = true,
    Duration thinkDuration = const Duration(milliseconds: 300),
    super.teams,
    super.onDiceRolled,
    super.onPieceMoved,
    super.onPieceCaptured,
    super.onTurnChanged,
    super.onPlayerWon,
    super.onTeamWon,
    super.onGameFinished,
    super.stepAnimationDuration,
    super.botDifficulty = LudoBotDifficulty.medium,
  }) : super(botPlayers: botPlayerIndices, botThinkDuration: thinkDuration);

  /// Same as [botPlayers].
  Set<int> get botPlayerIndices => botPlayers;

  /// Same as [botThinkDuration].
  Duration get thinkDuration => botThinkDuration;

  /// Returns this controller; kept for compatibility.
  LudoController get innerController => this;
}
