import 'dart:async';

import 'package:goodlock_app/net/match_link.dart';
import 'package:goodlock_app/net/models.dart';

/// A link with no network: tests push what the server would send and read what the client sent.
class FakeLink implements MatchLink {
  final _rooms = StreamController<RoomView>.broadcast(sync: true);
  final _states = StreamController<GameStateView>.broadcast(sync: true);
  final _resolved = StreamController<RoundResolved>.broadcast(sync: true);
  final _over = StreamController<GameOver>.broadcast(sync: true);
  final _presence = StreamController<PresenceChanged>.broadcast(sync: true);
  final _errors = StreamController<String>.broadcast(sync: true);
  final sent = <String>[];

  @override
  Stream<RoomView> get rooms => _rooms.stream;
  @override
  Stream<GameStateView> get states => _states.stream;
  @override
  Stream<RoundResolved> get resolved => _resolved.stream;
  @override
  Stream<GameOver> get gameOver => _over.stream;
  @override
  Stream<PresenceChanged> get presence => _presence.stream;
  @override
  Stream<String> get errors => _errors.stream;

  void server(GameStateView s) => _states.add(s);
  void serverResolved(RoundResolved r) => _resolved.add(r);
  void serverOver(GameOver o) => _over.add(o);
  void serverError(String m) => _errors.add(m);

  @override
  void confirmSelection(List<String> catalogIds) =>
      sent.add('confirmSelection ${catalogIds.join(',')}');
  @override
  void cancelSelection() => sent.add('cancelSelection');
  @override
  void rearrangeTeam(List<String?> slots) =>
      sent.add('rearrangeTeam ${slots.map((s) => s ?? '-').join(',')}');
  @override
  void confirmPlacement() => sent.add('confirmPlacement');
  @override
  void cancelPlacement() => sent.add('cancelPlacement');
  @override
  void confirmKeep(List<String> lockedCharacterIds) =>
      sent.add('confirmKeep ${lockedCharacterIds.join(',')}');
  @override
  void cancelKeep() => sent.add('cancelKeep');
  @override
  void concede() => sent.add('concede');
}
