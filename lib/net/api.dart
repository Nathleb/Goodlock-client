import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);
  @override
  String toString() => 'ApiException($status): $message';
}

class Tokens {
  final String accessToken;
  final String refreshToken;
  const Tokens(this.accessToken, this.refreshToken);
}

/// REST side of the backend: auth, collection, decks.
class Api {
  final String baseUrl;
  final http.Client _http;
  String? accessToken;

  Api(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  Future<Tokens> register(String username, String password) => _auth('register', username, password);
  Future<Tokens> login(String username, String password) => _auth('login', username, password);

  Future<Tokens> _auth(String route, String username, String password) async {
    final j = await _send('POST', '/auth/$route', {'username': username, 'password': password}) as Json;
    final tokens = Tokens(j['accessToken'] as String, j['refreshToken'] as String);
    accessToken = tokens.accessToken;
    return tokens;
  }

  Future<List<CatalogCharacter>> collection() async {
    final j = await _send('GET', '/collection') as Json;
    return (j['characters'] as List).map((c) => CatalogCharacter.fromJson(c as Json)).toList();
  }

  Future<List<Deck>> decks() async {
    final j = await _send('GET', '/decks') as Json;
    return (j['decks'] as List).map((d) => Deck.fromJson(d as Json)).toList();
  }

  Future<Deck> createDeck(String name, List<String> characterIds) async =>
      Deck.fromJson(await _send('POST', '/decks', {'name': name, 'characterIds': characterIds}) as Json);

  Future<Deck> updateDeck(String id, String name, List<String> characterIds) async =>
      Deck.fromJson(await _send('PUT', '/decks/$id', {'name': name, 'characterIds': characterIds}) as Json);

  Future<void> deleteDeck(String id) => _send('DELETE', '/decks/$id');

  Future<Object?> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['content-type'] = 'application/json';
    if (accessToken != null) request.headers['authorization'] = 'Bearer $accessToken';
    if (body != null) request.body = jsonEncode(body);

    final response = await http.Response.fromStream(await _http.send(request));
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _message(decoded) ?? response.reasonPhrase ?? 'HTTP error');
    }
    return decoded;
  }

  // Nest errors: { message: string | string[] }
  static String? _message(Object? decoded) {
    if (decoded is! Map) return null;
    final m = decoded['message'];
    return m is List ? m.join('\n') : m?.toString();
  }
}
