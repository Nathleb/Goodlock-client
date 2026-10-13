import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/session.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
