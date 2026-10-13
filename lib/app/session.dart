import 'package:shared_preferences/shared_preferences.dart';

import '../net/api.dart';

/// App-wide connection state: which server, and the authenticated API client.
class AppSession {
  static const _serverKey = 'serverUrl';
  static const defaultServer = 'http://localhost:3000';

  String serverUrl;
  Api? api;
  String? username;

  AppSession(this.serverUrl);

  static Future<AppSession> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppSession(prefs.getString(_serverKey) ?? defaultServer);
    } catch (_) {
      return AppSession(defaultServer); // storage unavailable: still usable
    }
  }

  Future<void> setServer(String url) async {
    serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverKey, serverUrl);
    } catch (_) {}
  }

  Future<void> signIn(String user, String password, {required bool register}) async {
    final client = Api(serverUrl);
    if (register) {
      await client.register(user, password);
    } else {
      await client.login(user, password);
    }
    api = client;
    username = user;
  }

  void signOut() {
    api = null;
    username = null;
  }
}
