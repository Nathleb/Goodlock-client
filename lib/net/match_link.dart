import 'models.dart';

/// What a screen needs from the connection to play a match: the server's events and the player's
/// commands. [GameSocket] implements it; tests use a fake with no network.
abstract class MatchLink {
  Stream<RoomView> get rooms;
  Stream<GameStateView> get states;
  Stream<RoundResolved> get resolved;
  Stream<GameOver> get gameOver;
  Stream<PresenceChanged> get presence;
  Stream<String> get errors;

  void confirmSelection(List<String> catalogIds);
  void cancelSelection();
  void rearrangeTeam(List<String?> slots);
  void confirmPlacement();
  void cancelPlacement();
  void confirmKeep(List<String> lockedCharacterIds);
  void cancelKeep();
  void concede();
}
