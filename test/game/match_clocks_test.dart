import 'package:flutter_test/flutter_test.dart';
import 'package:goodlock_app/game/match_clocks.dart';
import 'package:goodlock_app/net/models.dart';

PlayerClock clock(int remainingMs, {bool running = true, bool connected = true, int reconnectionMs = 180000}) =>
    PlayerClock(remainingMs: remainingMs, reconnectionMs: reconnectionMs, running: running, connected: connected);

GameStateView state(List<PlayerClock> clocks) => GameStateView(
      phase: Phase.keep,
      currentRound: 0,
      initiativePlayerIndex: 0,
      rollsLeft: 2,
      clocks: clocks,
      players: const [PlayerView(0, []), PlayerView(1, [])],
    );

final t0 = DateTime(2026, 11, 9, 12);
DateTime after(int ms) => t0.add(Duration(milliseconds: ms));

void main() {
  test('nothing to show before the first state', () {
    expect(MatchClocks(0).read(0, t0), isNull);
  });

  test('my own clock counts down from the moment the state arrives, while it runs (CLOCK-2)', () {
    final clocks = MatchClocks(0)..onState(state([clock(60000), clock(60000)]), t0);

    expect(clocks.read(0, t0)!.remainingMs, 60000);
    expect(clocks.read(0, after(2500))!.remainingMs, 57500);
  });

  test('my own clock stays put while it does not run (I confirmed, or no decision phase)', () {
    final clocks = MatchClocks(0)..onState(state([clock(60000, running: false), clock(60000)]), t0);

    expect(clocks.read(0, after(5000))!.remainingMs, 60000);
  });

  test("the opponent's clock never counts down locally: it shows the last state until the next one", () {
    final clocks = MatchClocks(1)..onState(state([clock(45000), clock(50000)]), t0);

    expect(clocks.read(0, after(10000))!.remainingMs, 45000);
    expect(clocks.read(1, after(10000))!.remainingMs, 40000);

    clocks.onState(state([clock(38000), clock(40000)]), after(10000));
    expect(clocks.read(0, after(12000))!.remainingMs, 38000);
  });

  test('a clock stops at 0 rather than going negative (CLOCK-3)', () {
    final clocks = MatchClocks(0)..onState(state([clock(1000), clock(1000)]), t0);

    expect(clocks.read(0, after(5000))!.remainingMs, 0);
  });

  test("a disconnected player's reconnection time counts down for both players, the opponent's included (AWAY-2, GAME-7)", () {
    final clocks = MatchClocks(0)
      ..onState(state([clock(60000), clock(60000, connected: false, reconnectionMs: 100000)]), t0);

    expect(clocks.read(1, after(4000))!.reconnectionMs, 96000);
    expect(clocks.read(1, after(4000))!.remainingMs, 60000, reason: "the opponent's thinking time stays static");
    expect(clocks.read(0, after(4000))!.reconnectionMs, 180000, reason: 'a connected player keeps their reconnection time');
    expect(clocks.read(1, after(200000))!.reconnectionMs, 0);
  });

  test('presenceChanged starts and stops the reconnection time of that player only', () {
    final clocks = MatchClocks(0)..onState(state([clock(60000), clock(60000)]), t0);

    clocks.onPresence(const PresenceChanged(1, false, 170000), after(1000));
    expect(clocks.read(1, after(3000))!.connected, isFalse);
    expect(clocks.read(1, after(3000))!.reconnectionMs, 168000);
    expect(clocks.read(0, after(3000))!.remainingMs, 57000, reason: 'my own clock keeps counting from its own state');

    clocks.onPresence(const PresenceChanged(1, true, 168000), after(3000));
    expect(clocks.read(1, after(9000))!.connected, isTrue);
    expect(clocks.read(1, after(9000))!.reconnectionMs, 168000);
  });

  test('a state that carries no clocks keeps the clocks already shown', () {
    final clocks = MatchClocks(0)..onState(state([clock(60000), clock(60000)]), t0);

    clocks.onState(state(const []), after(1000));
    expect(clocks.read(0, after(1000))!.remainingMs, 59000);
  });

  test('the clocks freeze when the match ends', () {
    final clocks = MatchClocks(0)
      ..onState(state([clock(60000), clock(60000, connected: false, reconnectionMs: 100000)]), t0)
      ..stop(after(2000));

    expect(clocks.read(0, after(9000))!.remainingMs, 58000);
    expect(clocks.read(1, after(9000))!.reconnectionMs, 98000);
  });

  test('formatClock reads minutes and seconds, rounding up so 0:00 means the time is out', () {
    expect(formatClock(600000), '10:00');
    expect(formatClock(65000), '1:05');
    expect(formatClock(59001), '1:00');
    expect(formatClock(1), '0:01');
    expect(formatClock(0), '0:00');
  });
}
