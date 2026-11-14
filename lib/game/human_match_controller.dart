import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../net/match_link.dart';
import '../net/models.dart';
import '../net/rules.dart';
import 'match_clocks.dart';

/// A round the Flame scene has to play: the board of the Keep it started from, and what the server resolved.
class PlayableRound {
  final List<CharacterView> start;
  final List<ResolveStep> log;
  const PlayableRound(this.start, this.log);
}

/// The player's side of a match: it follows the server's states and keeps what the player is editing
/// (the picks of the Selection, the layout of the Placement, the dice kept in a Keep), until they confirm.
/// Plain Dart over a [MatchLink]; screens only render it and call it. It computes no outcome: faces, HP and
/// statuses come from the server.
class HumanMatchController extends ChangeNotifier {
  final MatchLink link;
  final int me;
  final DateTime Function() now;
  final MatchClocks clocks;

  GameStateView? state;
  GameOver? over;
  String? error;

  /// SEL-2: the catalog ids the player keeps, in the order they chose them.
  List<String> picks = [];

  /// PLACE-2: a character id per cell of my side, null for the empty cell.
  List<String?> layout = List<String?>.filled(boardSize, null);
  int? selectedSlot;

  /// KEEP-1: the ids of my characters whose die is kept.
  Set<String> locks = {};

  final _rounds = Queue<PlayableRound>();
  bool _playing = false;
  String? _keepKey;
  final _subs = <StreamSubscription<Object?>>[];

  HumanMatchController(this.link, {required this.me, DateTime Function()? now})
      : now = now ?? DateTime.now,
        clocks = MatchClocks(me) {
    _subs.addAll([
      link.states.listen(_onState),
      link.resolved.listen(_onResolved),
      link.gameOver.listen((o) {
        over = o;
        clocks.stop(this.now());
        notifyListeners();
      }),
      link.presence.listen((p) {
        clocks.onPresence(p, this.now());
        notifyListeners();
      }),
      link.errors.listen((m) {
        error = m;
        notifyListeners();
      }),
    ]);
  }

  Phase? get phase => state?.phase;
  bool get ready => state?.myReady ?? false;
  List<CharacterView> get myTeam => state?.players[me].team ?? const [];
  bool get isResolving => _playing || _rounds.isNotEmpty;
  bool get hasRoundToPlay => _rounds.isNotEmpty;
  bool get showResult => over != null && !isResolving;

  /// The Confirm button: a Selection needs exactly [teamSize] picks; once confirmed it reads Cancel (GAME-8).
  bool get canConfirm {
    if (state == null || ready || isResolving) return false;
    return switch (phase) {
      Phase.selection => picks.length == teamSize,
      Phase.placement || Phase.keep => true,
      _ => false,
    };
  }

  bool get canCancel => state != null && ready && !isResolving && const [Phase.selection, Phase.placement, Phase.keep].contains(phase);

  void _onState(GameStateView gs) {
    state = gs;
    clocks.onState(gs, now());
    switch (gs.phase) {
      case Phase.selection:
        final mine = gs.selection?.myPicks;
        if (gs.myReady && mine != null) picks = List.of(mine);
      case Phase.placement:
        layout = List<String?>.filled(boardSize, null);
        for (final c in gs.players[me].team) {
          layout[c.position.slot] = c.id;
        }
        selectedSlot = null;
      case Phase.keep:
        final key = '${gs.currentRound}/${gs.rollsLeft}';
        if (key != _keepKey) {
          _keepKey = key;
          locks = {for (final c in gs.players[me].team) if (c.isFaceLocked) c.id};
        }
      default:
        break;
    }
    notifyListeners();
  }

  void _onResolved(RoundResolved r) {
    // The state just before this event is this round's Keep board, with its shields still in place.
    final start = state?.players.expand((p) => p.team).toList() ?? const <CharacterView>[];
    clocks.onState(r.gameState, now());
    if (start.isNotEmpty) _rounds.add(PlayableRound(start, r.resolveLog));
    notifyListeners();
  }

  /// The next round for the scene to play, or null. Call [roundPlayed] when it has played.
  PlayableRound? nextRound() {
    if (_rounds.isEmpty) return null;
    _playing = true;
    return _rounds.removeFirst();
  }

  void roundPlayed() {
    _playing = false;
    notifyListeners();
  }

  void togglePick(String catalogId) {
    if (phase != Phase.selection || ready) return;
    if (!picks.remove(catalogId) && picks.length < teamSize) picks.add(catalogId);
    notifyListeners();
  }

  /// Two taps move a character: first the character, then a cell; an occupied cell swaps the two.
  void tapCell(int slot) {
    if (phase != Phase.placement || ready || slot < 0 || slot >= boardSize) return;
    final from = selectedSlot;
    if (from == null) {
      if (layout[slot] != null) selectedSlot = slot;
    } else if (from == slot) {
      selectedSlot = null;
    } else {
      final moved = layout[from];
      layout[from] = layout[slot];
      layout[slot] = moved;
      selectedSlot = null;
      link.rearrangeTeam(List.of(layout));
    }
    notifyListeners();
  }

  void toggleLock(String characterId) {
    if (phase != Phase.keep || ready || isResolving) return;
    if (!locks.remove(characterId)) locks.add(characterId);
    notifyListeners();
  }

  void confirm() {
    if (!canConfirm) return;
    switch (phase) {
      case Phase.selection:
        link.confirmSelection(List.of(picks));
      case Phase.placement:
        link.confirmPlacement();
      case Phase.keep:
        link.confirmKeep(locks.toList());
      default:
        break;
    }
  }

  void cancel() {
    if (!canCancel) return;
    switch (phase) {
      case Phase.selection:
        link.cancelSelection();
      case Phase.placement:
        link.cancelPlacement();
      case Phase.keep:
        link.cancelKeep();
      default:
        break;
    }
  }

  void concede() => link.concede();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
