import 'package:flutter/material.dart';
import 'package:flutter_ludo/flutter_ludo.dart';

void main() => runApp(const LudoExampleApp());

class LudoExampleApp extends StatelessWidget {
  const LudoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ludo example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const LudoExampleScreen(),
    );
  }
}

class LudoExampleScreen extends StatefulWidget {
  const LudoExampleScreen({super.key});

  @override
  State<LudoExampleScreen> createState() => _LudoExampleScreenState();
}

class _LudoExampleScreenState extends State<LudoExampleScreen> {
  late final LudoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LudoController(
      players: const [
        LudoPlayer(name: 'Red', color: Colors.red),
        LudoPlayer(name: 'Green', color: Colors.green),
        LudoPlayer(name: 'Yellow', color: Color(0xFFE6C200)),
        LudoPlayer(name: 'Blue', color: Colors.blue),
      ],
      diceRules: const LudoDiceRules(
        startAllowedValues: [6],
        extraTurnValues: [6],
      ),
      onPlayerWon: (playerIndex, place) {
        final name = _controller.state.players[playerIndex].name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name finished in place $place!')),
        );
      },
      onGameFinished: (winnersInOrder) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game over!')),
        );
      },
    );
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
        title: const Text('flutter_ludo example'),
        actions: [
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_controller.reset),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LudoGame(controller: _controller),
        ),
      ),
    );
  }
}