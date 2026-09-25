import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

void main() => runApp(const LudoExampleApp());

class LudoExampleApp extends StatelessWidget {
  const LudoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ludo example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_ludo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoTile(
            icon: Icons.tune,
            title: 'Quick match',
            subtitle: 'Built-in setup screen: players, bots, difficulty, teams',
            builder: (_) => const LudoSetup(),
          ),
          _DemoTile(
            icon: Icons.dark_mode_outlined,
            title: 'Quick match (dark theme)',
            subtitle: 'Same screen with LudoTheme.dark',
            builder: (_) => const LudoSetup(theme: LudoTheme.dark),
          ),
          _DemoTile(
            icon: Icons.smart_toy_outlined,
            title: 'You vs 3 hard bots',
            subtitle:
                'Code-driven controller with events, hints, pause, '
                'and save/restore',
            builder: (_) => const CustomGameScreen(),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(body: builder(context)),
          ),
        ),
      ),
    );
  }
}

/// Shows how to drive the game from your own code.
class CustomGameScreen extends StatefulWidget {
  const CustomGameScreen({super.key});

  @override
  State<CustomGameScreen> createState() => _CustomGameScreenState();
}

class _CustomGameScreenState extends State<CustomGameScreen> {
  late final LudoController _controller;
  String? _savedGame;

  @override
  void initState() {
    super.initState();
    _controller = LudoController(
      players: const [
        LudoPlayer(name: 'You', color: Color(0xFFE53935)),
        LudoPlayer(name: 'Bolt', color: Color(0xFF1E88E5)),
        LudoPlayer(name: 'Chip', color: Color(0xFF43A047)),
        LudoPlayer(name: 'Dot', color: Color(0xFFFFB300)),
      ],
      botPlayers: {1, 2, 3},
      botDifficulty: LudoBotDifficulty.hard,
      diceRules: const LudoDiceRules.modern(),
      onPieceCaptured: (captured, by) {
        final players = _controller.state.players;
        _toast(
          '${players[by.playerIndex].name} captured '
          '${players[captured.playerIndex].name}!',
        );
      },
      onTurnForfeited: (player, streak) => _toast(
        '${_controller.state.players[player].name} rolled $streak sixes '
        '— turn lost',
      ),
      onPlayerWon: (player, place) =>
          _toast('${_controller.state.players[player].name} finished #$place'),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _hint() {
    final move = _controller.suggestMove();
    if (move == null) {
      _toast('Roll first, then ask for a hint.');
      return;
    }
    final from = move.fromPosition == LudoPiece.home
        ? 'out of home'
        : 'from cell ${move.fromPosition}';
    _toast('Try piece ${move.pieceId % 4 + 1} $from');
  }

  void _save() {
    // In a real app, write this string to shared_preferences or a file.
    _savedGame = jsonEncode(_controller.state.toJson());
    _toast('Game saved');
    setState(() {});
  }

  void _load() {
    final saved = _savedGame;
    if (saved == null) return;
    _controller.restore(
      LudoGameState.fromJson(jsonDecode(saved) as Map<String, Object?>),
    );
    _toast('Game restored');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('You vs 3 bots'),
        actions: [
          IconButton(
            tooltip: 'Hint',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _hint,
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: _controller.isPaused ? 'Resume' : 'Pause',
              icon: Icon(_controller.isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _controller.isPaused
                  ? _controller.resume
                  : _controller.pause,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'save':
                  _save();
                case 'load':
                  _load();
                case 'new':
                  _controller.reset();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'save', child: Text('Save game')),
              PopupMenuItem(
                value: 'load',
                enabled: _savedGame != null,
                child: const Text('Load saved game'),
              ),
              const PopupMenuItem(value: 'new', child: Text('New game')),
            ],
          ),
        ],
      ),
      body: LudoGame(controller: _controller),
    );
  }
}
