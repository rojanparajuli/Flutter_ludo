import 'package:flutter/material.dart';
import 'package:flutter_ludo/service/ludo_team.dart';

import '../bot/ludo_bot_controller.dart';
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
  ChangeNotifier? _controller;

  static const List<_PlayerDef> _defaults = [
    _PlayerDef('Red',    Color(0xFFE53935)),
    _PlayerDef('Blue',   Color(0xFF1E88E5)),
    _PlayerDef('Green',  Color(0xFF43A047)),
    _PlayerDef('Yellow', Color(0xFFFFB300)),
  ];

  int      _count     = 4;
  bool     _teamsMode = false;
  Set<int> _botSeats  = {};

  void _startGame() {
    final players = List.generate(
      _count,
      (i) => LudoPlayer(name: _defaults[i].name, color: _defaults[i].color),
    );
    final teams = (_teamsMode && _count == 4) ? kDefaultTeams : null;

    setState(() {
      if (_botSeats.isEmpty) {
        _controller = LudoController(
          players:     players,
          diceRules:   widget.diceRules,
          enableAudio: widget.enableAudio,
          teams:       teams,
        );
      } else {
        _controller = LudoBotController(
          players:          players,
          botPlayerIndices: _botSeats,
          diceRules:        widget.diceRules,
          enableAudio:      widget.enableAudio,
          teams:            teams,
        );
      }
    });
  }

  void _backToSetup() {
    if (_controller is LudoController) {
      (_controller as LudoController).dispose();
    } else if (_controller is LudoBotController) {
      (_controller as LudoBotController).dispose();
    }
    setState(() => _controller = null);
  }

  @override
  void dispose() {
    if (_controller is LudoController) {
      (_controller as LudoController).dispose();
    } else if (_controller is LudoBotController) {
      (_controller as LudoBotController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return _SetupScreen(
        count:              _count,
        teamsMode:          _teamsMode,
        botSeats:           _botSeats,
        defaults:           _defaults,
        onCountChanged:     (v) => setState(() {
          _count = v;
          if (v != 4) _teamsMode = false;
          _botSeats = _botSeats.where((s) => s < v).toSet();
        }),
        onTeamsModeChanged: (v) => setState(() => _teamsMode = v),
        onBotSeatToggled:   (seat) => setState(() {
          if (_botSeats.contains(seat)) {
            _botSeats = {..._botSeats}..remove(seat);
          } else {
            _botSeats = {..._botSeats, seat};
          }
        }),
        onStart: _startGame,
      );
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        if (ctrl is LudoBotController) {
          return LudoGame(
            botController: ctrl,
            theme:         widget.theme,
            onBack:        _backToSetup,
          );
        }
        return LudoGame(
          controller: ctrl as LudoController,
          theme:      widget.theme,
          onBack:     _backToSetup,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup screen widget
// ─────────────────────────────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({
    required this.count,
    required this.teamsMode,
    required this.botSeats,
    required this.defaults,
    required this.onCountChanged,
    required this.onTeamsModeChanged,
    required this.onBotSeatToggled,
    required this.onStart,
  });

  final int                  count;
  final bool                 teamsMode;
  final Set<int>             botSeats;
  final List<_PlayerDef>     defaults;
  final ValueChanged<int>    onCountChanged;
  final ValueChanged<bool>   onTeamsModeChanged;
  final ValueChanged<int>    onBotSeatToggled;
  final VoidCallback         onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('LUDO',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Color(0xFF212121),
                      )),
                  const SizedBox(height: 4),
                  Text('Classic board game',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2)),

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
                                  child: Text('$n',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      )),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Player type'),
                        const SizedBox(height: 4),
                        Text('Tap a seat to toggle between Human and Bot',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(height: 14),
                        ...List.generate(count, (i) {
                          final def   = defaults[i];
                          final isBot = botSeats.contains(i);
                          return GestureDetector(
                            onTap: () => onBotSeatToggled(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 130),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isBot
                                    ? def.color.withValues(alpha: 0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isBot
                                      ? def.color.withValues(alpha: 0.6)
                                      : Colors.grey.shade200,
                                  width: isBot ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                      color: def.color,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Text(def.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                const Spacer(),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBot
                                        ? const Color(0xFF212121)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isBot
                                            ? Icons.smart_toy_rounded
                                            : Icons.person_rounded,
                                        size: 14,
                                        color: isBot
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isBot ? 'Bot' : 'Human',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isBot
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Teams mode toggle (4 players only)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: count == 4
                        ? _Card(
                            child: Row(children: [
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
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              // FIX 1: activeColor deprecated → use activeTrackColor + thumbColor
                              Switch(
                                value: teamsMode,
                                onChanged: onTeamsModeChanged,
                                activeTrackColor: const Color(0xFF212121),
                                activeThumbColor: Colors.white,
                              ),
                            ]),
                          )
                        : const SizedBox.shrink(),
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
                        child: Text('Start Game',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
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

class _PlayerDef {
  const _PlayerDef(this.name, this.color);
  final String name;
  final Color  color;
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
        letterSpacing: 0.3,
      ));
}

// ─────────────────────────────────────────────────────────────────────────────
// LudoGame — accepts either LudoController or LudoBotController
// ─────────────────────────────────────────────────────────────────────────────

class LudoGame extends StatelessWidget {
  const LudoGame({
    super.key,
    this.controller,
    this.botController,
    this.theme         = LudoTheme.defaultTheme,
    this.showDice      = true,
    this.showStatusBar = true,
    this.onBack,
  }) : assert(controller != null || botController != null,
            'Provide either controller or botController.');

  final LudoController?    controller;
  final LudoBotController? botController;
  final LudoTheme          theme;
  final bool               showDice;
  final bool               showStatusBar;
  final VoidCallback?      onBack;

  // FIX 2: removed unused _innerController, _isAnimating, _animatingPiece
  // FIX 3: expose innerController as a public getter on LudoBotController
  //        (done in ludo_bot_controller.dart — see below)
  LudoGameState get _state     => botController?.state ?? controller!.state;
  bool          get _isBotTurn => botController?.isCurrentPlayerBot ?? false;

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            if (showStatusBar)
              _TopBar(
                state:    state,
                onBack:   onBack,
                botSeats: botController?.botPlayerIndices ?? {},
              ),
            const SizedBox(height: 4),
            if (showStatusBar) _TurnPill(state: state, isBotTurn: _isBotTurn),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildBoard(),
              ),
            ),
            if (showDice) _buildDice(),
          ]),
          if (state.isFinished)
            _GameOverOverlay(state: state, onPlayAgain: _reset),
        ]),
      ),
    );
  }

  Widget _buildBoard() {
    if (botController != null) {
      return LudoBoard(
        // FIX 3: use public innerController getter instead of _inner
        controller: botController!.innerController,
        theme: theme,
      );
    }
    return LudoBoard(controller: controller!, theme: theme);
  }

  Widget _buildDice() {
    if (botController != null) {
      return _BotAwareLudoDice(botController: botController!);
    }
    return LudoDice(controller: controller!);
  }

  void _reset() {
    botController?.reset();
    controller?.reset();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bot-aware dice — disables roll button during bot turns
// ─────────────────────────────────────────────────────────────────────────────

class _BotAwareLudoDice extends StatefulWidget {
  const _BotAwareLudoDice({required this.botController});
  final LudoBotController botController;

  @override
  State<_BotAwareLudoDice> createState() => _BotAwareLudoDiceState();
}

class _BotAwareLudoDiceState extends State<_BotAwareLudoDice>
    with SingleTickerProviderStateMixin {
  late AnimationController _shake;
  late Animation<double>   _dx;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _dx = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -3.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _roll() {
    _shake.forward(from: 0);
    widget.botController.rollDice();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl      = widget.botController;
    final state     = ctrl.state;
    final isBotTurn = ctrl.isCurrentPlayerBot;
    final canRoll   = !state.isFinished &&
                      state.phase == LudoTurnPhase.awaitingRoll &&
                      !ctrl.isAnimating &&
                      !isBotTurn;

    final playerColor = state.isFinished
        ? Colors.grey.shade400
        : state.players[state.currentPlayerIndex].color;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _dx,
            builder: (_, child) =>
                Transform.translate(offset: Offset(_dx.value, 0), child: child),
            child: _DiceFace(value: state.diceValue, color: playerColor),
          ),
          const SizedBox(width: 20),
          _RollButton(
            label: isBotTurn
                ? 'Bot thinking…'
                : ctrl.isAnimating
                    ? 'Moving…'
                    : 'Roll',
            canRoll: canRoll,
            color:   playerColor,
            onTap:   canRoll ? _roll : null,
          ),
          const SizedBox(width: 10),
          _AudioToggle(
            enabled:  ctrl.enableAudio,
            onToggle: ctrl.toggleAudio,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared dice / button / audio widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DiceFace extends StatelessWidget {
  const _DiceFace({required this.value, required this.color});
  final int?  value;
  final Color color;

  static const Map<int, List<List<int>>> _pips = {
    1: [[1,1]],
    2: [[0,0],[2,2]],
    3: [[0,0],[1,1],[2,2]],
    4: [[0,0],[0,2],[2,0],[2,2]],
    5: [[0,0],[0,2],[1,1],[2,0],[2,2]],
    6: [[0,0],[0,2],[1,0],[1,2],[2,0],[2,2]],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: value != null ? color : Colors.grey.shade300,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: value == null
          ? Center(
              child: Text('–',
                  style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600)))
          : CustomPaint(
              painter: _PipPainter(pips: _pips[value!]!, color: color)),
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter({required this.pips, required this.color});
  final List<List<int>> pips;
  final Color           color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const pad   = 8.0;
    final step  = (size.width - pad * 2) / 2;
    final r     = size.width * 0.09;
    for (final pip in pips) {
      canvas.drawCircle(
          Offset(pad + pip[1] * step, pad + pip[0] * step), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.pips != pips || old.color != color;
}

class _RollButton extends StatelessWidget {
  const _RollButton({
    required this.label,
    required this.canRoll,
    required this.color,
    this.onTap,
  });
  final String        label;
  final bool          canRoll;
  final Color         color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: canRoll ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: canRoll ? color : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
              color: canRoll ? Colors.white : Colors.grey.shade500,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
      ),
    );
  }
}

class _AudioToggle extends StatefulWidget {
  const _AudioToggle({required this.enabled, required this.onToggle});
  final bool               enabled;
  final ValueChanged<bool> onToggle;

  @override
  State<_AudioToggle> createState() => _AudioToggleState();
}

class _AudioToggleState extends State<_AudioToggle> {
  late bool _on;

  @override
  void initState() {
    super.initState();
    _on = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_on ? Icons.volume_up : Icons.volume_off),
      color: _on ? Colors.blueGrey : Colors.grey.shade400,
      iconSize: 22,
      onPressed: () {
        setState(() => _on = !_on);
        widget.onToggle(_on);
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
    required this.botSeats,
    this.onBack,
  });
  final LudoGameState state;
  final Set<int>      botSeats;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        if (onBack != null) ...[
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back, size: 22,
                color: Color(0xFF424242)),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: state.isTeamsMode
              ? _TeamsStatusRow(state: state, botSeats: botSeats)
              : _PlayersStatusRow(state: state, botSeats: botSeats),
        ),
      ]),
    );
  }
}

class _PlayersStatusRow extends StatelessWidget {
  const _PlayersStatusRow({required this.state, required this.botSeats});
  final LudoGameState state;
  final Set<int>      botSeats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < state.players.length; i++)
          _PlayerChip(
            player:   state.players[i],
            isActive: i == state.currentPlayerIndex && !state.isFinished,
            isBot:    botSeats.contains(i),
            place:    state.winners.contains(i)
                ? state.winners.indexOf(i) + 1
                : null,
          ),
      ],
    );
  }
}

class _TeamsStatusRow extends StatelessWidget {
  const _TeamsStatusRow({required this.state, required this.botSeats});
  final LudoGameState state;
  final Set<int>      botSeats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: state.teams!.map((team) {
        final isActive =
            team.contains(state.currentPlayerIndex) && !state.isFinished;
        final won =
            team.playerIndices.every((i) => state.winners.contains(i));
        return _TeamChip(
          team: team, players: state.players,
          isActive: isActive, won: won,
        );
      }).toList(),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.isActive,
    required this.isBot,
    this.place,
  });
  final LudoPlayer player;
  final bool       isActive;
  final bool       isBot;
  final int?       place;

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
          color: isActive ? player.color : Colors.grey.shade300,
          width: isActive ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9, height: 9,
            decoration:
                BoxDecoration(color: player.color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(player.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? player.color : Colors.grey.shade500,
            )),
        if (isBot) ...[
          const SizedBox(width: 4),
          Icon(Icons.smart_toy_rounded,
              size: 11,
              color: isActive ? player.color : Colors.grey.shade400),
        ],
        if (place != null) ...[
          const SizedBox(width: 4),
          Text(['🥇', '🥈', '🥉', '🏅'][place! - 1],
              style: const TextStyle(fontSize: 11)),
        ],
      ]),
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
  final LudoTeam         team;
  final List<LudoPlayer> players;
  final bool             isActive;
  final bool             won;

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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8, height: 8,
            decoration:
                BoxDecoration(color: p0.color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Container(
            width: 8, height: 8,
            decoration:
                BoxDecoration(color: p1.color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(team.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive ? p0.color : Colors.grey.shade500,
            )),
        if (won) ...[
          const SizedBox(width: 4),
          const Text('🏆', style: TextStyle(fontSize: 11)),
        ],
      ]),
    );
  }
}

class _TurnPill extends StatelessWidget {
  const _TurnPill({required this.state, required this.isBotTurn});
  final LudoGameState state;
  final bool          isBotTurn;

  @override
  Widget build(BuildContext context) {
    if (state.isFinished) return const SizedBox.shrink();
    final player = state.players[state.currentPlayerIndex];

    String label;
    if (state.isTeamsMode) {
      final team = state.teamOf(state.currentPlayerIndex);
      label = team != null
          ? '${player.name} (${team.name})${isBotTurn ? ' 🤖' : ''}'
          : player.name;
    } else {
      label = isBotTurn ? '${player.name} 🤖' : "${player.name}'s turn";
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(state.currentPlayerIndex),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: player.color.withValues(alpha: 0.10),
          border:
              Border.all(color: player.color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: player.color,
            )),
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
    required this.onPlayAgain,
  });
  final LudoGameState state;
  final VoidCallback  onPlayAgain;

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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  state.isTeamsMode ? '🏆 Team Wins!' : 'Game Over',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (state.isTeamsMode)
                _TeamsResult(state: state)
              else
                _StandardResult(state: state),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onPlayAgain,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212121),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('Play Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        )),
                  ),
                ),
              ),
            ]),
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
    return Column(children: [
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(winning.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          for (final pi in winning.playerIndices) ...[
            Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                    color: state.players[pi].color,
                    shape: BoxShape.circle)),
            const SizedBox(width: 3),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      for (final t in state.teams!)
        if (t != winning)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🥈', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(t.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
    ]);
  }
}

class _StandardResult extends StatelessWidget {
  const _StandardResult({required this.state});
  final LudoGameState state;

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉', '🏅'];
    return Column(children: [
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
                    shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(state.players[state.winners[i]].name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
    ]);
  }
}