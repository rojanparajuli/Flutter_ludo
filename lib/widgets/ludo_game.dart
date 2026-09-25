import 'package:flutter/material.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../bot/ludo_bot_controller.dart';
import '../bot/ludo_bot_strategy.dart';
import '../controller/ludo_controller.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_player.dart';
import '../themes/ludo_theme.dart';
import 'ludo_board.dart';
import 'ludo_dice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Setup screen
// ─────────────────────────────────────────────────────────────────────────────

/// A complete, self-contained Ludo app screen: a setup page (player count,
/// human/bot seats, bot difficulty, teams mode, rule set) that launches a
/// [LudoGame] and returns to setup when the player taps back.
///
/// ```dart
/// MaterialApp(home: LudoSetup())
/// ```
class LudoSetup extends StatefulWidget {
  const LudoSetup({
    super.key,
    this.theme = LudoTheme.defaultTheme,
    this.diceRules = const LudoDiceRules(),
    @Deprecated('Audio was removed in 0.1.0. This flag has no effect.')
    this.enableAudio = true,
    this.players,
    this.initialBotSeats = const {1, 2, 3},
    this.botDifficulty = LudoBotDifficulty.medium,
    this.botThinkDuration = const Duration(milliseconds: 500),
    this.stepAnimationDuration = const Duration(milliseconds: 180),
  }) : assert(
         players == null || players.length == 4,
         'Provide exactly 4 player presets (one per seat).',
       );

  final LudoTheme theme;

  /// Rules used when "Modern rules" is off.
  final LudoDiceRules diceRules;
  final bool enableAudio;

  /// Names and colors for the 4 seats, in seat order (top-left, top-right,
  /// bottom-right, bottom-left). Defaults to Red, Blue, Green, Yellow.
  final List<LudoPlayer>? players;

  /// Seats pre-selected as bots on the setup page.
  final Set<int> initialBotSeats;

  /// Initially selected bot difficulty.
  final LudoBotDifficulty botDifficulty;

  final Duration botThinkDuration;
  final Duration stepAnimationDuration;

  static const List<LudoPlayer> defaultPlayers = [
    LudoPlayer(name: 'Red', color: Color(0xFFE53935)),
    LudoPlayer(name: 'Blue', color: Color(0xFF1E88E5)),
    LudoPlayer(name: 'Green', color: Color(0xFF43A047)),
    LudoPlayer(name: 'Yellow', color: Color(0xFFFFB300)),
  ];

  @override
  State<LudoSetup> createState() => _LudoSetupState();
}

class _LudoSetupState extends State<LudoSetup> {
  LudoController? _controller;

  int _count = 4;
  bool _teamsMode = false;
  late Set<int> _botSeats;
  late LudoBotDifficulty _difficulty;
  late bool _modernRules;

  List<LudoPlayer> get _presets => widget.players ?? LudoSetup.defaultPlayers;

  @override
  void initState() {
    super.initState();
    _botSeats = {...widget.initialBotSeats.where((s) => s < _count)};
    _difficulty = widget.botDifficulty;
    _modernRules = widget.diceRules == const LudoDiceRules.modern();
  }

  void _startGame() {
    final players = _presets.take(_count).toList();
    final teams = (_teamsMode && _count == 4) ? kDefaultTeams : null;

    setState(() {
      _controller = LudoController(
        players: players,
        diceRules: _modernRules
            ? const LudoDiceRules.modern()
            : widget.diceRules,
        teams: teams,
        botPlayers: _botSeats,
        botDifficulty: _difficulty,
        botThinkDuration: widget.botThinkDuration,
        stepAnimationDuration: widget.stepAnimationDuration,
      );
    });
  }

  void _backToSetup() {
    _controller?.dispose();
    setState(() => _controller = null);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl != null) {
      return LudoGame(
        controller: ctrl,
        theme: widget.theme,
        onBack: _backToSetup,
      );
    }

    return _SetupScreen(
      theme: widget.theme,
      count: _count,
      teamsMode: _teamsMode,
      modernRules: _modernRules,
      botSeats: _botSeats,
      difficulty: _difficulty,
      players: _presets,
      onCountChanged: (v) => setState(() {
        _count = v;
        if (v != 4) _teamsMode = false;
        _botSeats = _botSeats.where((s) => s < v).toSet();
      }),
      onTeamsModeChanged: (v) => setState(() => _teamsMode = v),
      onModernRulesChanged: (v) => setState(() => _modernRules = v),
      onDifficultyChanged: (v) => setState(() => _difficulty = v),
      onBotSeatToggled: (seat) => setState(() {
        if (_botSeats.contains(seat)) {
          _botSeats = {..._botSeats}..remove(seat);
        } else {
          _botSeats = {..._botSeats, seat};
        }
      }),
      onStart: _startGame,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup screen widget
// ─────────────────────────────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({
    required this.theme,
    required this.count,
    required this.teamsMode,
    required this.modernRules,
    required this.botSeats,
    required this.difficulty,
    required this.players,
    required this.onCountChanged,
    required this.onTeamsModeChanged,
    required this.onModernRulesChanged,
    required this.onDifficultyChanged,
    required this.onBotSeatToggled,
    required this.onStart,
  });

  final LudoTheme theme;
  final int count;
  final bool teamsMode;
  final bool modernRules;
  final Set<int> botSeats;
  final LudoBotDifficulty difficulty;
  final List<LudoPlayer> players;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<bool> onTeamsModeChanged;
  final ValueChanged<bool> onModernRulesChanged;
  final ValueChanged<LudoBotDifficulty> onDifficultyChanged;
  final ValueChanged<int> onBotSeatToggled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final allBots = botSeats.length == count;
    return Material(
      color: theme.backgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LUDO',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classic board game',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.mutedTextColor,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Player count
                  _Card(
                    theme: theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Number of players', theme: theme),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [2, 3, 4].map((n) {
                            final sel = n == count;
                            return Semantics(
                              button: true,
                              selected: sel,
                              label: '$n players',
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: () => onCountChanged(n),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? theme.textColor
                                        : theme.dividerColor.withValues(
                                            alpha: 0.35,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sel
                                          ? theme.textColor
                                          : theme.dividerColor,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$n',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? theme.panelColor
                                            : theme.mutedTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Per-seat bot toggle
                  _Card(
                    theme: theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Players', theme: theme),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a seat to switch between Human and Bot',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(
                          count,
                          (i) => _SeatTile(
                            player: players[i],
                            isBot: botSeats.contains(i),
                            theme: theme,
                            onTap: () => onBotSeatToggled(i),
                          ),
                        ),
                        if (allBots)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'All seats are bots — sit back and watch.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.mutedTextColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bot difficulty
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: botSeats.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _Card(
                              theme: theme,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Label('Bot difficulty', theme: theme),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      for (final d in LudoBotDifficulty.values)
                                        Expanded(
                                          child: _Choice(
                                            label: _difficultyLabel(d),
                                            selected: d == difficulty,
                                            theme: theme,
                                            onTap: () => onDifficultyChanged(d),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 14),

                  _Card(
                    theme: theme,
                    child: _SwitchRow(
                      title: 'Modern rules',
                      subtitle: modernRules
                          ? 'Bonus roll on capture & finish · three 6s forfeit'
                          : 'Classic: only a 6 grants another roll',
                      value: modernRules,
                      theme: theme,
                      onChanged: onModernRulesChanged,
                    ),
                  ),

                  // Teams mode toggle (4 players only)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: count == 4
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _Card(
                              theme: theme,
                              child: _SwitchRow(
                                title: 'Teams mode (2v2)',
                                subtitle: teamsMode
                                    ? '${players[0].name}+${players[3].name}  vs  '
                                          '${players[1].name}+${players[2].name}'
                                    : 'Every player for themselves',
                                value: teamsMode,
                                theme: theme,
                                onChanged: onTeamsModeChanged,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),

                  const SizedBox(height: 24),

                  _PrimaryButton(
                    label: 'Start Game',
                    theme: theme,
                    onTap: onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _difficultyLabel(LudoBotDifficulty d) {
    switch (d) {
      case LudoBotDifficulty.easy:
        return 'Easy';
      case LudoBotDifficulty.medium:
        return 'Medium';
      case LudoBotDifficulty.hard:
        return 'Hard';
    }
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.player,
    required this.isBot,
    required this.theme,
    required this.onTap,
  });

  final LudoPlayer player;
  final bool isBot;
  final LudoTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${player.name}: ${isBot ? 'Bot' : 'Human'}',
      hint: 'Tap to switch',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isBot
                ? player.color.withValues(alpha: 0.08)
                : theme.panelColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBot
                  ? player.color.withValues(alpha: 0.6)
                  : theme.dividerColor,
              width: isBot ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: player.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                player.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textColor,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isBot
                      ? theme.textColor
                      : theme.dividerColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
                      size: 14,
                      color: isBot ? theme.panelColor : theme.mutedTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBot ? 'Bot' : 'Human',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isBot ? theme.panelColor : theme.mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final LudoTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.textColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? theme.textColor : theme.dividerColor,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? theme.panelColor : theme.mutedTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final LudoTheme theme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(title, theme: theme),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: theme.mutedTextColor),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: theme.textColor,
          thumbColor: WidgetStatePropertyAll(theme.panelColor),
          trackOutlineColor: WidgetStatePropertyAll(theme.dividerColor),
          inactiveTrackColor: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final LudoTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: theme.textColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: theme.panelColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.theme});
  final Widget child;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: theme.panelColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor),
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.theme});
  final String text;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: theme.textColor.withValues(alpha: 0.8),
      letterSpacing: 0.3,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LudoGame
// ─────────────────────────────────────────────────────────────────────────────

/// A full game screen: status bar, board, dice, and a game-over dialog.
/// Rebuilds automatically as [controller] changes.
///
/// Bot seats are configured on the controller:
///
/// ```dart
/// LudoGame(controller: LudoController(players: players, botPlayers: {1, 2, 3}))
/// ```
class LudoGame extends StatelessWidget {
  const LudoGame({
    super.key,
    this.controller,
    @Deprecated(
      'Pass a LudoController with botPlayers to `controller` instead.',
    )
    this.botController,
    this.theme = LudoTheme.defaultTheme,
    this.showDice = true,
    this.showStatusBar = true,
    this.showGameOverOverlay = true,
    this.onBack,
    this.onPlayAgain,
  }) : assert(
         controller != null || botController != null,
         'Provide a controller.',
       );

  final LudoController? controller;

  // ignore: deprecated_member_use_from_same_package
  final LudoBotController? botController;
  final LudoTheme theme;
  final bool showDice;
  final bool showStatusBar;

  /// Whether to cover the board with results when the game ends.
  final bool showGameOverOverlay;

  /// Shows a back arrow in the status bar when non-null.
  final VoidCallback? onBack;

  /// Called by the game-over "Play Again" button. Defaults to
  /// `controller.reset()`.
  final VoidCallback? onPlayAgain;

  LudoController get _controller => controller ?? botController!;

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final state = ctrl.state;
        return Material(
          color: theme.backgroundColor,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    if (showStatusBar) ...[
                      _TopBar(
                        state: state,
                        theme: theme,
                        onBack: onBack,
                        botSeats: ctrl.botPlayers,
                      ),
                      const SizedBox(height: 4),
                      _TurnPill(
                        state: state,
                        isBotTurn: ctrl.isCurrentPlayerBot,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Center(
                          child: LudoBoard(controller: ctrl, theme: theme),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (showDice) LudoDice(controller: ctrl, theme: theme),
                  ],
                ),
                if (state.isFinished && showGameOverOverlay)
                  _GameOverOverlay(
                    state: state,
                    theme: theme,
                    onPlayAgain: onPlayAgain ?? ctrl.reset,
                    onBack: onBack,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status bar widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.theme,
    required this.botSeats,
    this.onBack,
  });
  final LudoGameState state;
  final LudoTheme theme;
  final Set<int> botSeats;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back, size: 22, color: theme.textColor),
            ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: state.isTeamsMode
                  ? _TeamsStatusRow(state: state, theme: theme)
                  : _PlayersStatusRow(
                      state: state,
                      theme: theme,
                      botSeats: botSeats,
                    ),
            ),
          ),
          if (onBack != null) const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PlayersStatusRow extends StatelessWidget {
  const _PlayersStatusRow({
    required this.state,
    required this.theme,
    required this.botSeats,
  });
  final LudoGameState state;
  final LudoTheme theme;
  final Set<int> botSeats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < state.players.length; i++)
          _PlayerChip(
            player: state.players[i],
            theme: theme,
            isActive: i == state.currentPlayerIndex && !state.isFinished,
            isBot: botSeats.contains(i),
            finished: state.finishedCountOf(i),
            place: state.winners.contains(i)
                ? state.winners.indexOf(i) + 1
                : null,
          ),
      ],
    );
  }
}

class _TeamsStatusRow extends StatelessWidget {
  const _TeamsStatusRow({required this.state, required this.theme});
  final LudoGameState state;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: state.teams!.map((team) {
        final isActive =
            team.contains(state.currentPlayerIndex) && !state.isFinished;
        final won = team.playerIndices.every((i) => state.winners.contains(i));
        return _TeamChip(
          team: team,
          players: state.players,
          theme: theme,
          isActive: isActive,
          won: won,
        );
      }).toList(),
    );
  }
}

const _medals = ['🥇', '🥈', '🥉', '🏅'];

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.theme,
    required this.isActive,
    required this.isBot,
    required this.finished,
    this.place,
  });
  final LudoPlayer player;
  final LudoTheme theme;
  final bool isActive;
  final bool isBot;
  final int finished;
  final int? place;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? player.color.withValues(alpha: 0.12)
            : Colors.transparent,
        border: Border.all(
          color: isActive ? player.color : theme.dividerColor,
          width: isActive ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: player.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            player.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? player.color : theme.mutedTextColor,
            ),
          ),
          if (isBot) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.smart_toy_rounded,
              size: 11,
              color: isActive ? player.color : theme.mutedTextColor,
            ),
          ],
          if (place != null) ...[
            const SizedBox(width: 4),
            Text(_medals[place! - 1], style: const TextStyle(fontSize: 11)),
          ] else if (finished > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$finished/4',
              style: TextStyle(fontSize: 10, color: theme.mutedTextColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.team,
    required this.players,
    required this.theme,
    required this.isActive,
    required this.won,
  });
  final LudoTeam team;
  final List<LudoPlayer> players;
  final LudoTheme theme;
  final bool isActive;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final p0 = players[team.playerIndices[0]];
    final p1 = players[team.playerIndices[1]];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? p0.color.withValues(alpha: 0.08) : Colors.transparent,
        border: Border.all(
          color: isActive ? p0.color : theme.dividerColor,
          width: isActive ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: p0.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: p1.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            team.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? p0.color : theme.mutedTextColor,
            ),
          ),
          if (won) ...[
            const SizedBox(width: 4),
            const Text('🏆', style: TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _TurnPill extends StatefulWidget {
  const _TurnPill({required this.state, required this.isBotTurn});
  final LudoGameState state;
  final bool isBotTurn;

  @override
  State<_TurnPill> createState() => _TurnPillState();
}

class _TurnPillState extends State<_TurnPill> {
  // Keys the AnimatedSwitcher child. Must be unique per turn, not per
  // player: with fast bots, play can cycle back to a player while that
  // player's previous pill is still fading out.
  int _turnSerial = 0;

  @override
  void didUpdateWidget(_TurnPill old) {
    super.didUpdateWidget(old);
    if (old.state.currentPlayerIndex != widget.state.currentPlayerIndex) {
      _turnSerial++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isBotTurn = widget.isBotTurn;
    if (state.isFinished) return const SizedBox(height: 22);
    final player = state.currentPlayer;

    String label;
    if (state.isTeamsMode) {
      final team = state.teamOf(state.currentPlayerIndex);
      label = team != null
          ? '${player.name} (${team.name})${isBotTurn ? ' 🤖' : ''}'
          : player.name;
    } else {
      label = isBotTurn ? '${player.name} 🤖' : "${player.name}'s turn";
    }

    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey(_turnSerial),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: player.color.withValues(alpha: 0.10),
            border: Border.all(color: player.color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: player.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game over overlay
// ─────────────────────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.state,
    required this.theme,
    required this.onPlayAgain,
    this.onBack,
  });
  final LudoGameState state;
  final LudoTheme theme;
  final VoidCallback onPlayAgain;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: theme.panelColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.isTeamsMode ? '🏆 Team Wins!' : 'Game Over',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (state.isTeamsMode)
                  _TeamsResult(state: state, theme: theme)
                else
                  _StandardResult(state: state, theme: theme),
                const SizedBox(height: 20),
                _PrimaryButton(
                  label: 'Play Again',
                  theme: theme,
                  onTap: onPlayAgain,
                ),
                if (onBack != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onBack,
                    child: Text(
                      'Change setup',
                      style: TextStyle(color: theme.mutedTextColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamsResult extends StatelessWidget {
  const _TeamsResult({required this.state, required this.theme});
  final LudoGameState state;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) {
    final winning = state.winningTeam;
    if (winning == null) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                winning.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(width: 8),
              for (final pi in winning.playerIndices) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: state.players[pi].color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final t in state.teams!)
          if (t != winning)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🥈', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  t.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

class _StandardResult extends StatelessWidget {
  const _StandardResult({required this.state, required this.theme});
  final LudoGameState state;
  final LudoTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < state.winners.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(_medals[i], style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: state.players[state.winners[i]].color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.players[state.winners[i]].name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
