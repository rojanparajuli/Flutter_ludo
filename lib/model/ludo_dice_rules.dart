import 'package:flutter/foundation.dart';

/// Configurable dice behaviour and turn rules.
///
/// Board geometry, capture rules, and win conditions are fixed by the
/// flutter_ludo specification, but how the dice interacts with a piece
/// leaving home, and when a player earns an extra turn, is configurable
/// per game. For example:
///
/// ```dart
/// LudoDiceRules(startAllowedValues: [6])       // classic
/// LudoDiceRules(startAllowedValues: [1, 6])    // easier variant
/// LudoDiceRules(extraTurnValues: [6])          // classic
/// LudoDiceRules(extraTurnValues: [1, 6])       // generous variant
/// LudoDiceRules(extraTurnValues: [])           // no extra turns at all
/// LudoDiceRules(forfeitStreak: 3)              // three 6s in a row forfeit
/// LudoDiceRules.modern()                       // popular mobile-app rules
/// ```
@immutable
class LudoDiceRules {
  const LudoDiceRules({
    this.startAllowedValues = const [6],
    this.extraTurnValues = const [6],
    this.extraTurnOnCapture = false,
    this.extraTurnOnFinish = false,
    this.forfeitStreak,
  }) : assert(
         forfeitStreak == null || forfeitStreak > 0,
         'forfeitStreak must be positive.',
       );

  /// The rule set used by most modern Ludo apps: start on a 6, a 6 grants
  /// another roll, capturing or finishing a piece grants another roll, and
  /// a third consecutive 6 forfeits the turn.
  const LudoDiceRules.modern()
    : startAllowedValues = const [6],
      extraTurnValues = const [6],
      extraTurnOnCapture = true,
      extraTurnOnFinish = true,
      forfeitStreak = 3;

  /// Dice values that allow a piece to leave the home base and enter the
  /// board. Defaults to `[6]`, the traditional rule.
  final List<int> startAllowedValues;

  /// Dice values that grant the current player an additional turn instead
  /// of passing play to the next player. Defaults to `[6]`. Pass an empty
  /// list to disable extra turns entirely.
  final List<int> extraTurnValues;

  /// Whether capturing an opponent piece grants an extra turn.
  /// Defaults to `false`.
  final bool extraTurnOnCapture;

  /// Whether moving a piece onto the final (center) cell grants an extra
  /// turn. Defaults to `false`.
  final bool extraTurnOnFinish;

  /// When non-null, rolling a value from [extraTurnValues] this many times
  /// in a row forfeits that roll and passes play to the next player — e.g.
  /// `3` implements the classic "three sixes and you're out" rule.
  /// Defaults to `null` (no limit).
  final int? forfeitStreak;

  bool canStartWith(int diceValue) => startAllowedValues.contains(diceValue);

  bool grantsExtraTurn(int diceValue) => extraTurnValues.contains(diceValue);

  LudoDiceRules copyWith({
    List<int>? startAllowedValues,
    List<int>? extraTurnValues,
    bool? extraTurnOnCapture,
    bool? extraTurnOnFinish,
    int? forfeitStreak,
    bool clearForfeitStreak = false,
  }) {
    return LudoDiceRules(
      startAllowedValues: startAllowedValues ?? this.startAllowedValues,
      extraTurnValues: extraTurnValues ?? this.extraTurnValues,
      extraTurnOnCapture: extraTurnOnCapture ?? this.extraTurnOnCapture,
      extraTurnOnFinish: extraTurnOnFinish ?? this.extraTurnOnFinish,
      forfeitStreak: clearForfeitStreak
          ? null
          : (forfeitStreak ?? this.forfeitStreak),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LudoDiceRules &&
          listEquals(other.startAllowedValues, startAllowedValues) &&
          listEquals(other.extraTurnValues, extraTurnValues) &&
          other.extraTurnOnCapture == extraTurnOnCapture &&
          other.extraTurnOnFinish == extraTurnOnFinish &&
          other.forfeitStreak == forfeitStreak);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(startAllowedValues),
    Object.hashAll(extraTurnValues),
    extraTurnOnCapture,
    extraTurnOnFinish,
    forfeitStreak,
  );
}
