import 'package:flutter/material.dart';

import '../controller/ludo_controller.dart';
import '../model/ludo_dice_rules.dart';
import '../model/ludo_game_state.dart';
import '../model/ludo_player.dart';
import '../themes/ludo_theme.dart';
import 'ludo_board.dart';
import 'ludo_dice.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Player setup screen – choose 2 to 4 players before game starts
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps the game with a setup screen that asks how many players (2–4)
/// before creating the [LudoController].
///
/// Usage (replace your existing game entry point):
/// ```dart
/// LudoSetup(
///   onStart: (controller) => Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => LudoGame(controller: controller)),
///   ),
/// )
/// ```
///
/// Or embed it directly so it transitions inline:
/// ```dart
/// LudoSetup()
/// ```
class LudoSetup extends StatefulWidget {
  const LudoSetup({
    super.key,
    this.theme = LudoTheme.defaultTheme,
    this.diceRules = const LudoDiceRules(),
    this.enableAudio = true,
  });

  final LudoTheme    theme;
  final LudoDiceRules diceRules;
  final bool         enableAudio;

  @override
  State<LudoSetup> createState() => _LudoSetupState();
}

class _LudoSetupState extends State<LudoSetup> {
  LudoController? _controller;

  // Default player definitions – colour matches kHomeBaseOrigins order.
  static const List<_PlayerDef> _defaults = [
    _PlayerDef('Red',    Color(0xFFE53935)),
    _PlayerDef('Blue',   Color(0xFF1E88E5)),
    _PlayerDef('Green',  Color(0xFF43A047)),
    _PlayerDef('Yellow', Color(0xFFFFB300)),
  ];

  int _count = 4;

  void _startGame() {
    final players = List.generate(
      _count,
      (i) => LudoPlayer(name: _defaults[i].name, color: _defaults[i].color),
    );
    setState(() {
      _controller = LudoController(
        players: players,
        diceRules: widget.diceRules,
        enableAudio: widget.enableAudio,
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
        count: _count,
        defaults: _defaults,
        onCountChanged: (v) => setState(() => _count = v),
        onStart: _startGame,
      );
    }

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => LudoGame(
        controller: ctrl,
        theme: widget.theme,
        onBack: _backToSetup,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup screen widget
// ─────────────────────────────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({
    required this.count,
    required this.defaults,
    required this.onCountChanged,
    required this.onStart,
  });

  final int                  count;
  final List<_PlayerDef>     defaults;
  final ValueChanged<int>    onCountChanged;
  final VoidCallback         onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
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

                  const SizedBox(height: 40),

                  // Player count selector
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Number of players',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [2, 3, 4].map((n) {
                            final selected = n == count;
                            return GestureDetector(
                              onTap: () => onCountChanged(n),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF212121)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
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
                                      color: selected
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

                  const SizedBox(height: 20),

                  // Player colour preview
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Players',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(count, (i) {
                            final def = defaults[i];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: def.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: def.color.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  def.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

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

class _PlayerDef {
  const _PlayerDef(this.name, this.color);
  final String name;
  final Color  color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main game widget (board + dice + status)
// ─────────────────────────────────────────────────────────────────────────────

class LudoGame extends StatelessWidget {
  const LudoGame({
    super.key,
    required this.controller,
    this.theme = LudoTheme.defaultTheme,
    this.showDice = true,
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
            child: Stack(
              children: [
                Column(
                  children: [
                    if (showStatusBar) _TopBar(state: state, onBack: onBack),
                    const SizedBox(height: 6),
                    if (showStatusBar) _TurnPill(state: state),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: LudoBoard(controller: controller, theme: theme),
                      ),
                    ),
                    if (showDice) LudoDice(controller: controller),
                  ],
                ),
                if (state.isFinished)
                  _GameOverOverlay(state: state, controller: controller),
              ],
            ),
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
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.arrow_back, size: 22, color: Color(0xFF424242)),
            ),
          if (onBack != null) const SizedBox(width: 8),
          // Player chips
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < state.players.length; i++)
                  _PlayerChip(
                    player: state.players[i],
                    isActive: i == state.currentPlayerIndex && !state.isFinished,
                    place: state.winners.contains(i)
                        ? state.winners.indexOf(i) + 1
                        : null,
                  ),
              ],
            ),
          ),
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
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: player.color, shape: BoxShape.circle),
          ),
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
            Text(
              ['🥇','🥈','🥉','🏅'][place! - 1],
              style: const TextStyle(fontSize: 12),
            ),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(state.currentPlayerIndex),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: player.color.withValues(alpha: 0.10),
          border: Border.all(color: player.color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "${player.name}'s turn",
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
// Game over overlay
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
                const Text('Game Over',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                for (var i = 0; i < state.winners.length; i++)
                  _WinRow(
                    place: i + 1,
                    player: state.players[state.winners[i]],
                  ),
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

class _WinRow extends StatelessWidget {
  const _WinRow({required this.place, required this.player});
  final int        place;
  final LudoPlayer player;

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇','🥈','🥉','🏅'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(medals[place - 1], style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: player.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(player.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}