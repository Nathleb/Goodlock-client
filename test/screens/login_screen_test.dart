import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/app/session.dart';
import 'package:goodlock_app/screens/login_screen.dart';

void main() {
  testWidgets('the login form fits a landscape phone without overflow', (tester) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: AppSession('http://localhost:3000'))));
    await tester.pump();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
