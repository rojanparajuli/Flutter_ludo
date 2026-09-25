import 'package:flutter_ludo/flutter_ludo.dart';
import 'package:flutter_ludo_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen opens the custom bot game', (tester) async {
    await tester.pumpWidget(const LudoExampleApp());
    expect(find.text('Quick match'), findsOneWidget);

    await tester.tap(find.text('You vs 3 hard bots'));
    await tester.pumpAndSettle();
    expect(find.byType(LudoGame), findsOneWidget);
    expect(find.text("You's turn"), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Resume'), findsOneWidget);

    // Leave the screen so the controller is disposed.
    await tester.pageBack();
    await tester.pumpAndSettle();
  });
}
