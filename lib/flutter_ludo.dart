/// flutter_ludo
///
/// A reusable, production-ready Ludo game engine and board widget for
/// Flutter — fixed rules and board geometry, configurable dice behaviour,
/// and a clean controller-based architecture. See the package README for
/// a full usage guide.
// ignore: unnecessary_library_name
library flutter_ludo;

export 'constant/board_constants.dart';
export 'controller/ludo_controller.dart';
export 'engine/ludo_engine.dart';
export 'model/legal_move.dart';
export 'model/ludo_dice_rules.dart';
export 'model/ludo_game_state.dart';
export 'model/ludo_piece.dart';
export 'model/ludo_player.dart';
export 'model/piece_state.dart';
export 'rules/capture_rules.dart';
export 'rules/move_validator.dart';
export 'rules/piece_state_rules.dart';
export 'rules/win_rules.dart';
export 'themes/ludo_theme.dart';
export 'widgets/ludo_board.dart';
export 'widgets/ludo_dice.dart';
export 'widgets/ludo_game.dart';