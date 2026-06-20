import 'package:flutter/material.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../controller/ludo_controller.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_player.dart';
import '../themes/ludo_theme.dart';
import 'ludo_board.dart';
import 'ludo_dice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LudoSetup — picks player count AND optional teams mode
// ─────────────────────────────────────────────────────────────────────────────

class LudoSetup extends StatefulWidget {
  const LudoSetup({
    super.key,
    this.theme       = LudoTheme.defaultTheme,
    this.diceRules   = const LudoDiceRules(),
    this.enableAudio = true,
  });

  final LudoTheme     theme;
  final LudoDiceRules diceRules;
  final bool          enableAudio;

  @override
  State<LudoSetup> createState() => _LudoSetupState();
}

class _LudoSetupState extends State<LudoSetup> {
  LudoController? _controller;

  static const List<_PlayerDef> _defaults = [
    _PlayerDef('Red',    Color(0xFFE53935)),
    _PlayerDef('Blue',   Color(0xFF1E88E5)),
    _PlayerDef('Green',  Color(0xFF43A047)),
    _PlayerDef('Yellow', Color(0xFFFFB300)),
  ];

  int  _count     = 4;
  bool _teamsMode = false;

  void _startGame() {
    final players = List.generate(
      _count,
      (i) => LudoPlayer(name: _defaults[i].name, color: _defaults[i].color),
    );

    // Teams mode is only valid with exactly 4 players
    final teams = (_teamsMode && _count == 4) ? kDefaultTeams : null;

    setState(() {
      _controller = LudoController(
        players:     players,
        diceRules:   widget.diceRules,
        enableAudio: widget.enableAudio,
        teams:       teams,
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
    if (ctrl == null) {
      return _SetupScreen(
        count:          _count,
        teamsMode:      _teamsMode,
        defaults:       _defaults,
        onCountChanged: (v) => setState(() {
          _count = v;
          if (v != 4) _teamsMode = false;
        }),
        onTeamsModeChanged: (v) => setState(() => _teamsMode = v),
        onStart: _startGame,
      );
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => LudoGame(
        controller: ctrl,
        theme:      widget.theme,
        onBack:     _backToSetup,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup screen
// ─────────────────────────────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({
    required this.count,
    required this.teamsMode,
    required this.defaults,
    required this.onCountChanged,
    required this.onTeamsModeChanged,
    required this.onStart,
  });

  final int                  count;
  final bool                 teamsMode;
  final List<_PlayerDef>     defaults;
  final ValueChanged<int>    onCountChanged;
  final ValueChanged<bool>   onTeamsModeChanged;
  final VoidCallback         onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    'LUDO',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classic board game',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Player count
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Number of players'),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [2, 3, 4].map((n) {
                            final sel = n == count;
                            return GestureDetector(
                              onTap: () => onCountChanged(n),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 130),
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? const Color(0xFF212121)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: sel
                                        ? const Color(0xFF212121)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? Colors.white
                                          : Colors.grey.shade600,
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

                  // Teams mode toggle (only shown for 4 players)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: count == 4
                        ? _Card(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _Label('Teams mode (2v2)'),
                                      const SizedBox(height: 2),
                                      Text(
                                        teamsMode
                                            ? 'Red+Yellow  vs  Blue+Green'
                                            : 'Every player for themselves',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: teamsMode,
                                  onChanged: onTeamsModeChanged,
                                  activeThumbColor: const Color(0xFF212121),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 14),

                  // Teams preview when enabled
                  if (teamsMode && count == 4) ...[
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Teams'),
                          const SizedBox(height: 12),
                          _TeamRow(
                            label: 'Team A',
                            players: [defaults[0], defaults[3]],
                          ),
                          const SizedBox(height: 8),
                          _TeamRow(
                            label: 'Team B',
                            players: [defaults[1], defaults[2]],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Players preview (non-teams mode)
                  if (!teamsMode)
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('Players'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: List.generate(count, (i) {
                              final d = defaults[i];
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14, height: 14,
                                    decoration: BoxDecoration(
                                      color: d.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(d.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Start button
                  GestureDetector(
                    onTap: onStart,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF212121),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Start Game',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.label, required this.players});
  final String            label;
  final List<_PlayerDef>  players;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        const Text('→', style: TextStyle(color: Colors.grey)),
        const SizedBox(width: 10),
        for (var i = 0; i < players.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('+',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: players[i].color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(players[i].name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _PlayerDef {
  const _PlayerDef(this.name, this.color);
  final String name;
  final Color  color;
}

// ─────────────────────────────────────────────────────────────────────────────
// LudoGame — main game screen
// ─────────────────────────────────────────────────────────────────────────────

class LudoGame extends StatelessWidget {
  const LudoGame({
    super.key,
    required this.controller,
    this.theme        = LudoTheme.defaultTheme,
    this.showDice     = true,
    this.showStatusBar = true,
    this.onBack,
  });

  final LudoController controller;
  final LudoTheme      theme;
  final bool           showDice;
  final bool           showStatusBar;
  final VoidCallback?  onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: SafeArea(
            child: Stack(children: [
              Column(children: [
                if (showStatusBar) _TopBar(state: state, onBack: onBack),
                const SizedBox(height: 4),
                if (showStatusBar) _TurnPill(state: state),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: LudoBoard(controller: controller, theme: theme),
                  ),
                ),
                if (showDice) LudoDice(controller: controller),
              ]),
              if (state.isFinished)
                _GameOverOverlay(state: state, controller: controller),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, this.onBack});
  final LudoGameState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        if (onBack != null) ...[
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back, size: 22, color: Color(0xFF424242)),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: state.isTeamsMode
              ? _TeamsStatusRow(state: state)
              : _PlayersStatusRow(state: state),
        ),
      ]),
    );
  }
}

/// Standard mode: one chip per player.
class _PlayersStatusRow extends StatelessWidget {
  const _PlayersStatusRow({required this.state});
  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < state.players.length; i++)
          _PlayerChip(
            player:   state.players[i],
            isActive: i == state.currentPlayerIndex && !state.isFinished,
            place:    state.winners.contains(i)
                ? state.winners.indexOf(i) + 1
                : null,
          ),
      ],
    );
  }
}

/// Teams mode: one chip per team with both player dots inside.
class _TeamsStatusRow extends StatelessWidget {
  const _TeamsStatusRow({required this.state});
  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    final teams = state.teams!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: teams.map((team) {
        final isActive = team.contains(state.currentPlayerIndex) && !state.isFinished;
        final won = team.playerIndices.every((i) => state.winners.contains(i));
        return _TeamChip(
          team:     team,
          players:  state.players,
          isActive: isActive,
          won:      won,
        );
      }).toList(),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.team,
    required this.players,
    required this.isActive,
    required this.won,
  });

  final LudoTeam        team;
  final List<LudoPlayer> players;
  final bool            isActive;
  final bool            won;

  @override
  Widget build(BuildContext context) {
    final p0 = players[team.playerIndices[0]];
    final p1 = players[team.playerIndices[1]];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? p0.color.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border.all(
          color: isActive ? p0.color : Colors.grey.shade300,
          width: isActive ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two small dots side by side
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: p0.color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: p1.color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            team.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? p0.color : Colors.grey.shade500,
            ),
          ),
          if (won) ...[
            const SizedBox(width: 4),
            const Text('🏆', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.isActive,
    this.place,
  });

  final LudoPlayer player;
  final bool       isActive;
  final int?       place;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? player.color.withValues(alpha: 0.12)
            : Colors.transparent,
        border: Border.all(
          color: isActive ? player.color : Colors.grey.shade300,
          width: isActive ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9,
              decoration: BoxDecoration(color: player.color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            player.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? player.color : Colors.grey.shade500,
            ),
          ),
          if (place != null) ...[
            const SizedBox(width: 4),
            Text(['🥇','🥈','🥉','🏅'][place! - 1],
                style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _TurnPill extends StatelessWidget {
  const _TurnPill({required this.state});
  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    if (state.isFinished) return const SizedBox.shrink();
    final player = state.players[state.currentPlayerIndex];

    String label;
    if (state.isTeamsMode) {
      final team = state.teamOf(state.currentPlayerIndex);
      label = team != null
          ? '${player.name} (${team.name}) — your turn'
          : "${player.name}'s turn";
    } else {
      label = "${player.name}'s turn";
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(state.currentPlayerIndex),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game-over overlay — teams mode shows winning team, standard shows podium
// ─────────────────────────────────────────────────────────────────────────────

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.state, required this.controller});
  final LudoGameState  state;
  final LudoController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.isTeamsMode ? '🏆 Team Wins!' : 'Game Over',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),

                if (state.isTeamsMode)
                  _TeamsResult(state: state)
                else
                  _StandardResult(state: state),

                const SizedBox(height: 20),
                GestureDetector(
                  onTap: controller.reset,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212121),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Play Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamsResult extends StatelessWidget {
  const _TeamsResult({required this.state});
  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    final winning = state.winningTeam;
    if (winning == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Winning team
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              // Colour dots
              for (final pi in winning.playerIndices) ...[
                Container(
                  width: 12, height: 12,
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
        const SizedBox(height: 10),
        // Losing team
        for (final t in state.teams!)
          if (t != winning)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🥈', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(t.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
      ],
    );
  }
}

class _StandardResult extends StatelessWidget {
  const _StandardResult({required this.state});
  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇','🥈','🥉','🏅'];
    return Column(
      children: [
        for (var i = 0; i < state.winners.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(medals[i], style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: state.players[state.winners[i]].color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.players[state.winners[i]].name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ]),
          ),
      ],
    );
  }
}