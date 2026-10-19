import 'package:flutter/material.dart';

import '../app/session.dart';
import '../net/api.dart';
import 'home_screen.dart';
import 'resolve_demo_screen.dart';

class LoginScreen extends StatefulWidget {
  final AppSession session;
  const LoginScreen({super.key, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _server = TextEditingController(text: widget.session.serverUrl);
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit({required bool register}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.setServer(_server.text);
      await widget.session.signIn(_user.text.trim(), _password.text, register: register);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(session: widget.session)));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Serveur injoignable ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Text('Goodlock', textAlign: TextAlign.center, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('prototype Flutter + Flame', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 32),
                TextField(controller: _user, decoration: const InputDecoration(labelText: 'Pseudo'), textInputAction: TextInputAction.next),
                const SizedBox(height: 12),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Mot de passe (8+)'), obscureText: true),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _busy ? null : () => _submit(register: false),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Se connecter'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : () => _submit(register: true),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Créer un compte'),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Démo Resolve hors ligne'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResolveDemoScreen())),
                ),
                const SizedBox(height: 24),
                ExpansionTile(
                  title: const Text('Serveur'),
                  subtitle: Text(widget.session.serverUrl, overflow: TextOverflow.ellipsis),
                  children: [
                    TextField(
                      controller: _server,
                      decoration: const InputDecoration(labelText: 'URL (ex. tunnel https://….trycloudflare.com)'),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
