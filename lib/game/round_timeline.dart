// The timeline of a round (TL-1, TL-3, TL-4), built from a start board and a resolve log.
// Pure Dart (no Flutter import). It only applies what the server sent: it computes no outcome.

import '../net/models.dart';
import 'playback.dart';

/// Why a token's action plays or not (TL-3).
enum TokenStatus { plays, blank, stunned, dead }

/// One action of the round, in resolution order (TL-1).
class TimelineToken {
  final String characterId;
  final DieFace face; // the actor's face at the start of the round
  final int team; // the actor's playerIndex at the start of the round
  final TokenStatus status;
  const TimelineToken(this.characterId, this.face, this.team, this.status);
}

/// The notches of a round (TL-4): notch 0 is the board before any action, notch i (1..tokens.length) the board
/// after token i-1, and the last notch the end of the round, shields reset.
///
/// Every board lists the characters of the start board, in its order. A character killed during the round stays
/// on the boards that follow it, with 0 hp, so the board can darken it.
class RoundTimeline {
  final List<TimelineToken> tokens;
  final List<List<CharacterView>> boards;

  /// The log the timeline was built from: `steps[i]` is the action of `tokens[i]`.
  final List<ResolveStep> steps;
  const RoundTimeline._(this.tokens, this.boards, this.steps);

  factory RoundTimeline.build(List<CharacterView> start, List<ResolveStep> log) {
    final atStart = {for (final c in start) c.id: c};
    final state = Map.of(atStart);
    final tokens = <TimelineToken>[];
    final boards = <List<CharacterView>>[List.unmodifiable(start)];
    for (final step in log) {
      final actor =
          atStart[step.characterId] ??
          (throw ArgumentError('Step of ${step.characterId}, who is not on the start board'));
      tokens.add(
        TimelineToken(
          actor.id,
          actor.face,
          actor.position.playerIndex,
          _status(step, actor.face, isDead: state[actor.id]!.isDead),
        ),
      );
      for (final change in step.changes) {
        final after = change.after;
        state[change.characterId] = after.isDead ? after.copyWith(hp: 0) : after;
      }
      boards.add(List.unmodifiable([for (final c in start) state[c.id]!]));
    }
    boards.add(List.unmodifiable(startOfNextRound(boards.last)));
    return RoundTimeline._(List.unmodifiable(tokens), List.unmodifiable(boards), List.unmodifiable(log));
  }

  int get notchCount => boards.length;

  List<CharacterView> boardAt(int notch) => boards[notch];

  /// The index of the token a notch plays; null on the start and end notches.
  int? stepAt(int notch) => notch == 0 || notch == notchCount - 1 ? null : notch - 1;
}

/// Judged on the state before the step: a skipped action is the actor's death or a stun.
TokenStatus _status(ResolveStep step, DieFace face, {required bool isDead}) {
  if (step.skipped) return isDead ? TokenStatus.dead : TokenStatus.stunned;
  return face.effects.isEmpty ? TokenStatus.blank : TokenStatus.plays;
}

/// The two players of a timeline board, as the board widget takes them, indexed by player: each team holds the
/// characters still alive, ordered by slot. A character with no HP left has left its cell (CELL-6, DEAD-1).
List<PlayerView> playersFromBoard(List<CharacterView> board) => [
  for (final player in [0, 1])
    PlayerView(
      player,
      [
        for (final c in board)
          if (c.position.playerIndex == player && !c.isDead) c,
      ]..sort((a, b) => a.position.slot.compareTo(b.position.slot)),
    ),
];
