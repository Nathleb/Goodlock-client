import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/app/session.dart';
import 'package:goodlock_app/main.dart';
import 'package:goodlock_app/screens/resolve_demo_screen.dart';

void main() {
  testWidgets('starts on the login screen with the configured server', (tester) async {
    await tester.pumpWidget(GoodlockApp(session: AppSession('https://example.trycloudflare.com')));
    expect(find.text('Goodlock'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('https://example.trycloudflare.com'), findsOneWidget);
  });

  testWidgets('the offline demo opens without a server', (tester) async {
    await tester.pumpWidget(GoodlockApp(session: AppSession('http://unreachable')));
    await tester.tap(find.text('Démo Resolve hors ligne'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ResolveDemoScreen), findsOneWidget);
  });
}
