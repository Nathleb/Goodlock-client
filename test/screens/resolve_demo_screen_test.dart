import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/screens/resolve_demo_screen.dart';

void main() {
  testWidgets('the offline demo fits a landscape phone without overflow', (tester) async {
    // A common 20:9 phone in landscape: 2400×1080 px at 2.625 dpr ≈ 914×411 dp.
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ResolveDemoScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Round suivant'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the demo's autoplay delay fire so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
  });
}
