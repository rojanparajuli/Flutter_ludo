import 'package:flutter/foundation.dart';

/// Configurable dice behaviour.
///
/// Board geometry, capture rules, and win conditions are fixed by the
/// flutter_ludo specification, but how the dice interacts with a piece
/// leaving home, and whether a roll earns an extra turn, is configurable
/// per game. For example:
///
/// ```dart
/// LudoDiceRules(startAllowedValues: [6])       // classic
/// LudoDiceRules(startAllowedValues: [1, 6])    // easier variant
/// LudoDiceRules(extraTurnValues: [6])          // classic
/// LudoDiceRules(extraTurnValues: [1, 6])       // generous variant
/// LudoDiceRules(extraTurnValues: [])           // no extra turns at all
/// ```
@immutable
class LudoDiceRules {
  const LudoDiceRules({
    this.startAllowedValues = const [6],
    this.extraTurnValues = const [6],
  });

  /// Dice values that allow a piece to leave the home base and enter the
  /// board. Defaults to `[6]`, the traditional rule.
  final List<int> startAllowedValues;

  /// Dice values that grant the current player an additional turn instead
  /// of passing play to the next player. Defaults to `[6]`. Pass an empty
  /// list to disable extra turns entirely.
  final List<int> extraTurnValues;

  bool canStartWith(int diceValue) => startAllowedValues.contains(diceValue);

  bool grantsExtraTurn(int diceValue) => extraTurnValues.contains(diceValue);
}