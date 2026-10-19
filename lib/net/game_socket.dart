import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'models.dart';

/// Typed wrapper over the backend's Socket.IO gateway (Goodlock-back session.gateway.ts).
class GameSocket {
  final io.Socket _socket;

  final _rooms = StreamController<RoomView>.broadcast();
  final _states = StreamController<GameStateView>.broadcast();
  final _resolved = StreamController<RoundResolved>.broadcast();
  final _gameOver = StreamController<GameOver>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _sessionId = Completer<String>();

  Stream<RoomView> get rooms => _rooms.stream; // roomCreated + roomUpdated
  Stream<GameStateView> get states => _states.stream; // gameStateUpdated
  Stream<RoundResolved> get resolved => _resolved.stream; // roundResolved
  Stream<GameOver> get gameOver => _gameOver.stream;
  Stream<String> get errors => _errors.stream;

  /// Sent by the server on connect; locate it in [RoomView.players] to know your player index.
  Future<String> get sessionId => _sessionId.future;

  GameSocket(String baseUrl, String accessToken)
      : _socket = io.io(
          baseUrl,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .setAuth({'token': accessToken})
              .disableAutoConnect()
              .enableReconnection()
              .enableForceNew() // one connection per GameSocket (no multiplexing by URL)
              .build(),
        ) {
    void room(dynamic data) => _rooms.add(RoomView.fromJson(_json(data)));
    _socket.on('roomCreated', room);
    _socket.on('roomUpdated', room);
    _socket.on('gameStateUpdated', (data) => _states.add(GameStateView.fromJson(_json(data))));
    _socket.on('roundResolved', (data) => _resolved.add(RoundResolved.fromJson(_json(data))));
    _socket.on('gameOver', (data) => _gameOver.add(GameOver.fromJson(_json(data))));
    _socket.on('error', (data) => _errors.add(data is Map ? '${data['message']}' : '$data'));
    _socket.on('sessionStarted', (data) {
      if (!_sessionId.isCompleted) _sessionId.complete(_json(data)['sessionId'] as String);
    });
  }

  /// Raw JSON of an event (e.g. to record fixtures).
  void onRaw(String event, void Function(Json json) handler) => _socket.on(event, (data) => handler(_json(data)));

  /// Resolves once the server accepted the connection (it disconnects on a bad token).
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) {
    final done = Completer<void>();
    _socket.onConnect((_) => done.isCompleted ? null : done.complete());
    _socket.onConnectError((e) => done.isCompleted ? null : done.completeError(StateError('connect error: $e')));
    _socket.connect();
    return done.future.timeout(timeout);
  }

  void dispose() {
    _socket.dispose();
    for (final c in [_rooms, _states, _resolved, _gameOver, _errors]) {
      c.close();
    }
  }

  // Lobby
  void createRoom() => _socket.emit('createRoom');
  void joinRoom(String roomId) => _socket.emit('joinRoom', {'roomId': roomId});
  void quitRoom() => _socket.emit('quitRoom');
  void selectDeck(String deckId) => _socket.emit('selectDeck', {'deckId': deckId});

  // Game
  void startGame() => _socket.emit('startGame');
  void confirmSelection(List<String> catalogIds) => _socket.emit('confirmSelection', {'characterIds': catalogIds});
  void cancelSelection() => _socket.emit('cancelSelection');
  /// [slots] reads like the board: a character id per cell, null for the empty cell.
  void rearrangeTeam(List<String?> slots) => _socket.emit('rearrangeTeam', {'slots': slots});
  void confirmPlacement() => _socket.emit('confirmPlacement');
  void cancelPlacement() => _socket.emit('cancelPlacement');
  void confirmKeep(List<String> lockedCharacterIds) =>
      _socket.emit('confirmKeep', {'lockedCharacterIds': lockedCharacterIds});
  void cancelKeep() => _socket.emit('cancelKeep');
  void claimVictory() => _socket.emit('claimVictory');

  static Json _json(dynamic data) => Map<String, dynamic>.from(data as Map);
}
