import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/session.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Forced landscape, full screen (the manifest also locks sensorLandscape, so there is no portrait flash).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final session = await AppSession.load();
  runApp(GoodlockApp(session: session));
}

class GoodlockApp extends StatelessWidget {
  final AppSession session;
  const GoodlockApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goodlock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A9D8F), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF14161F),
        useMaterial3: true,
      ),
      home: LoginScreen(session: session),
    );
  }
}
