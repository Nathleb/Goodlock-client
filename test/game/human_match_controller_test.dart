import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/human_match_controller.dart';
import 'package:goodlock_app/net/match_link.dart';
import 'package:goodlock_app/net/models.dart';

import '../helpers/builders.dart';

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
  void confirmSelection(List<String> catalogIds) => sent.add('confirmSelection ${catalogIds.join(',')}');
  @override
  void cancelSelection() => sent.add('cancelSelection');
  @override
  void rearrangeTeam(List<String?> slots) => sent.add('rearrangeTeam ${slots.map((s) => s ?? '-').join(',')}');
  @override
  void confirmPlacement() => sent.add('confirmPlacement');
  @override
  void cancelPlacement() => sent.add('cancelPlacement');
  @override
  void confirmKeep(List<String> lockedCharacterIds) => sent.add('confirmKeep ${lockedCharacterIds.join(',')}');
  @override
  void cancelKeep() => sent.add('cancelKeep');
  @override
  void concede() => sent.add('concede');
}

SelectionView selectionView({List<String>? myPicks}) => SelectionView([deckOf('a'), deckOf('b')], myPicks);

GameStateView selectionState({bool ready = false, List<String>? myPicks}) =>
    stateOf(Phase.selection, myReady: ready, selection: selectionView(myPicks: myPicks));

List<CharacterView> myTeam({List<String> locked = const []}) =>
    [for (var i = 0; i < 4; i++) character('m$i', side: 0, slot: i, locked: locked.contains('m$i'))];
List<CharacterView> theirTeam() => [for (var i = 0; i < 4; i++) character('t$i', side: 1, slot: i)];

GameStateView keepState({int round = 0, int rollsLeft = 2, bool ready = false, List<String> locked = const []}) =>
    stateOf(Phase.keep, round: round, rollsLeft: rollsLeft, myReady: ready, mine: myTeam(locked: locked), theirs: theirTeam());

void main() {
  late FakeLink link;
  late HumanMatchController c;

  setUp(() {
    link = FakeLink();
    c = HumanMatchController(link, me: 0, now: () => DateTime(2026));
  });

  group('SEL-2: the Selection', () {
    setUp(() => link.server(selectionState()));

    test('keeps a character when tapped and releases it when tapped again', () {
      c.togglePick('a0');
      c.togglePick('a1');
      expect(c.picks, ['a0', 'a1']);
      c.togglePick('a0');
      expect(c.picks, ['a1']);
    });

    test('keeps at most teamSize characters', () {
      for (final id in ['a0', 'a1', 'a2', 'a3', 'a4']) {
        c.togglePick(id);
      }
      expect(c.picks, ['a0', 'a1', 'a2', 'a3']);
    });

    test('can only confirm with exactly teamSize picks', () {
      c.togglePick('a0');
      expect(c.canConfirm, isFalse);
      for (final id in ['a1', 'a2', 'a3']) {
        c.togglePick(id);
      }
      expect(c.canConfirm, isTrue);
      c.confirm();
      expect(link.sent, ['confirmSelection a0,a1,a2,a3']);
    });

    test('GAME-8: after Confirm the player can cancel, and nothing else', () {
      for (final id in ['a0', 'a1', 'a2', 'a3']) {
        c.togglePick(id);
      }
      link.server(selectionState(ready: true, myPicks: ['a0', 'a1', 'a2', 'a3']));
      expect(c.canConfirm, isFalse);
      expect(c.canCancel, isTrue);
      c.togglePick('a4'); // locked while confirmed
      expect(c.picks, ['a0', 'a1', 'a2', 'a3']);
      c.cancel();
      expect(link.sent, ['cancelSelection']);
    });

    test('shows again the picks the server holds, for a player who comes back', () {
      link.server(selectionState(ready: true, myPicks: ['a5', 'a4', 'a3', 'a2']));
      expect(c.picks, ['a5', 'a4', 'a3', 'a2']);
    });
  });

  group('PLACE-1, PLACE-2: the Placement', () {
    setUp(() => link.server(stateOf(Phase.placement, mine: myTeam(), theirs: const [])));

    test('starts with the four characters on cells 0 to 3 and cell 4 empty', () {
      expect(c.layout, ['m0', 'm1', 'm2', 'm3', null]);
    });

    test('moves a character to an empty cell with two taps, and sends the whole layout', () {
      c.tapCell(1);
      expect(c.selectedSlot, 1);
      c.tapCell(4);
      expect(c.layout, ['m0', null, 'm2', 'm3', 'm1']);
      expect(c.selectedSlot, isNull);
      expect(link.sent, ['rearrangeTeam m0,-,m2,m3,m1']);
    });

    test('swaps two characters when the second tap is on an occupied cell', () {
      c.tapCell(0);
      c.tapCell(3);
      expect(c.layout, ['m3', 'm1', 'm2', 'm0', null]);
    });

    test('tapping the selected cell again deselects it, and tapping an empty cell first does nothing', () {
      c.tapCell(2);
      c.tapCell(2);
      expect(c.selectedSlot, isNull);
      c.tapCell(4);
      expect(c.selectedSlot, isNull);
      expect(link.sent, isEmpty);
    });

    test('GAME-8: cannot move once confirmed, and can cancel', () {
      link.server(stateOf(Phase.placement, myReady: true, mine: myTeam(), theirs: const []));
      c.tapCell(0);
      c.tapCell(4);
      expect(link.sent, isEmpty);
      expect(c.canCancel, isTrue);
      c.cancel();
      expect(link.sent, ['cancelPlacement']);
    });

    test('confirms the placement', () {
      expect(c.canConfirm, isTrue);
      c.confirm();
      expect(link.sent, ['confirmPlacement']);
    });
  });

  group('KEEP-1, FLOW-3: the Keep', () {
    test('starts with the dice the server says are kept, and toggles them', () {
      link.server(keepState(locked: ['m1']));
      expect(c.locks, {'m1'});
      c.toggleLock('m2');
      c.toggleLock('m1');
      expect(c.locks, {'m2'});
    });

    test('confirms with the kept dice', () {
      link.server(keepState());
      c.toggleLock('m0');
      c.toggleLock('m3');
      c.confirm();
      expect(link.sent, ['confirmKeep m0,m3']);
    });

    test('the second Keep starts from what the first one kept', () {
      link.server(keepState());
      c.toggleLock('m0');
      link.server(keepState(rollsLeft: 1, locked: ['m0']));
      expect(c.locks, {'m0'});
    });

    test('a new round starts with nothing kept', () {
      link.server(keepState(locked: ['m0']));
      link.server(keepState(round: 1));
      expect(c.locks, isEmpty);
    });

    test('keeps the player\'s edit when the server repeats the same Keep', () {
      link.server(keepState());
      c.toggleLock('m2');
      link.server(keepState());
      expect(c.locks, {'m2'});
    });

    test('GAME-8: after Confirm the dice cannot change, and the player can cancel', () {
      link.server(keepState());
      c.toggleLock('m0');
      link.server(keepState(ready: true, locked: ['m0']));
      c.toggleLock('m1');
      expect(c.locks, {'m0'});
      expect(c.canConfirm, isFalse);
      c.cancel();
      expect(link.sent, ['cancelKeep']);
    });
  });

  group('FLOW-4, FLOW-6: Resolve and the end of the match', () {
    RoundResolved resolvedRound() => RoundResolved(stateOf(Phase.resolve, mine: myTeam(), theirs: theirTeam()), const []);

    test('hands over the round to play with the Keep board as its start', () {
      link.server(keepState());
      link.serverResolved(resolvedRound());
      expect(c.isResolving, isTrue);

      final round = c.nextRound()!;
      expect(round.start.map((e) => e.id), ['m0', 'm1', 'm2', 'm3', 't0', 't1', 't2', 't3']);
      expect(c.nextRound(), isNull);
      expect(c.isResolving, isTrue); // still playing
      c.roundPlayed();
      expect(c.isResolving, isFalse);
    });

    test('shows the result only once the rounds are played', () {
      link.server(keepState());
      link.serverResolved(resolvedRound());
      link.serverOver(const GameOver(1, EndReason.elimination));
      expect(c.over, isNotNull);
      expect(c.showResult, isFalse);
      c.nextRound();
      c.roundPlayed();
      expect(c.showResult, isTrue);
    });

    test('AWAY-1: concedes', () {
      c.concede();
      expect(link.sent, ['concede']);
    });

    test('keeps the last error the server sent', () {
      link.serverError('Not your turn');
      expect(c.error, 'Not your turn');
    });
  });

  test('CLOCK-4: the clocks follow the states with the time given', () {
    var now = DateTime(2026);
    c = HumanMatchController(link, me: 0, now: () => now);
    link.server(keepState());
    now = now.add(const Duration(seconds: 10));
    expect(c.clocks.read(0, now)!.remainingMs, 590000);
    expect(c.clocks.read(1, now)!.remainingMs, 600000);
  });
}
