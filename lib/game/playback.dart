import '../net/models.dart';

/// The board at the start of the next round: the server resets shields in endOfRound
/// (dice are rerolled too, which the end notch of a round doesn't show).
List<CharacterView> startOfNextRound(List<CharacterView> endOfRound) =>
    [for (final c in endOfRound) c.copyWith(shield: 0)];
