import 'dart:math';

import '../app/session.dart';
import 'bot.dart';
import 'game_socket.dart';

/// A match of the signed-in player against a bot, set up on the real server.
class VsBotMatch {
  final GameSocket socket;
  final Bot bot;
  final int me;
  const VsBotMatch(this.socket, this.bot, this.me);

  void dispose() {
    try {
      socket.dispose();
    } catch (_) {}
    bot.dispose();
  }
}

/// Creates a room, seats a bot as the guest, chooses both decks and starts the match. The bot answers
/// every phase by itself (random picks, layout and kept dice).
Future<VsBotMatch> seatVsBot(AppSession session, String deckId, {Random? rng}) async {
  final api = session.api!;
  final socket = GameSocket(session.serverUrl, api.accessToken!);
  final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final bot = Bot('bot_$stamp', session.serverUrl, rng: rng);
  try {
    final sessionId = socket.sessionId;
    await socket.connect();
    final mine = await sessionId.timeout(const Duration(seconds: 5));
    await bot.setUp();

    final created = socket.rooms.first;
    socket.createRoom();
    final roomId = (await created.timeout(const Duration(seconds: 5))).roomId;

    final ready = socket.rooms.firstWhere((r) => r.players.length == 2 && r.players.every((p) => p.hasDeck));
    final joined = bot.socket.rooms.firstWhere((r) => r.players.length == 2);
    bot.socket.joinRoom(roomId);
    await joined.timeout(const Duration(seconds: 5));
    socket.selectDeck(deckId);
    bot.socket.selectDeck(bot.deckId);
    final room = await ready.timeout(const Duration(seconds: 5));

    final me = room.players.indexWhere((p) => p.playerId == mine);
    bot.seat(room);
    if (me < 0 || bot.me < 0 || me == bot.me) throw StateError('could not resolve seats');
    socket.startGame(); // the creator owns the room
    return VsBotMatch(socket, bot, me);
  } catch (_) {
    socket.dispose();
    bot.dispose();
    rethrow;
  }
}
