import 'dart:math' as math;

import '../../player/domain/player.dart';
import '../domain/match_event.dart';
import '../engine/match_engine.dart' show LiveGameSegment;
import 'play_by_play_phrases.dart';

/// Which team (if any) a [LiveBeat] belongs to -- the real-game analog of
/// `live_game_lab_screen.dart`'s private `_Team`, public here since a
/// real live-game screen (`TODO.md` item 8's stage 4, not built yet)
/// needs to consume it from outside this file.
enum LiveTeam { home, away }

/// Which zone (if any) a [LiveBeat]'s action happened in -- drives where
/// a blip lands, same shape as the Lab's own `_Zone` (`paint`/`midcourt`/
/// `threePoint`/`freeThrowLine`/`centerCourt`, after that file's own
/// 2026-08-18 geometry fix). `null` for a beat with no blip (there's no
/// real equivalent of the Lab's "team-level, no player" filler here --
/// every beat here comes from a real [MatchEvent], which always has a
/// real player).
enum LiveZone { paint, midcourt, threePoint, freeThrowLine, centerCourt }

/// A notable play worth calling out with a colored keyword badge --
/// mirrors the Lab's own `_Highlight`.
enum LiveHighlight { none, twoPointer, threePointer, andOne, steal, block }

extension LiveHighlightLabel on LiveHighlight {
  String? get label => switch (this) {
    LiveHighlight.none => null,
    LiveHighlight.twoPointer => '2PTS',
    LiveHighlight.threePointer => '3PTS',
    LiveHighlight.andOne => 'AND-1',
    LiveHighlight.steal => 'STEAL',
    LiveHighlight.block => 'BLOCK',
  };
}

/// One real, translated play-by-play beat -- the live-game analog of
/// `live_game_lab_screen.dart`'s private `_LabBeat`, but built from a
/// real [MatchEvent] via [LiveBeatTranslator] instead of a hand-authored
/// script (2026-08-18, `TODO.md` item 8's live-game architecture stage
/// 3). Deliberately doesn't carry the Lab's `isBreak`/`breakLabel` --
/// that's a coaching-break-sheet orchestration concern for whichever
/// screen consumes this (stage 4, not built yet), which already gets
/// told "this segment just completed a quarter" directly via
/// [LiveGameSegment.isEndOfQuarter] rather than needing a marker beat.
class LiveBeat {
  const LiveBeat({
    required this.team,
    this.zone,
    this.chipIndex,
    this.creditTeam,
    required this.displayText,
    this.highlight = LiveHighlight.none,
    this.isInbound = false,
    this.isPass = false,
    this.passFromZone,
    this.passFromChipIndex,
    this.isShotAttempt = false,
    this.shotMade,
    this.isFreeThrow = false,
    this.deltaHome = 0,
    this.deltaAway = 0,
    required this.clockSeconds,
    required this.quarter,
  });

  final LiveTeam? team;
  final LiveZone? zone;
  final int? chipIndex;

  /// Who gets credit for this beat -- the badge, the blip's color, and
  /// the "(POS TEAM)" tag all read off this. Defaults to [team]; overridden
  /// for a defensive highlight (a block/steal), where the play still
  /// happens at the *offense's* end ([team]) but the credited player is
  /// on the other side.
  final LiveTeam? creditTeam;

  /// The fully-resolved play-by-play sentence -- already contains any
  /// `{player}`/`{player2}`/`{team}`/`{opponent}` tags filled in.
  final String displayText;
  final LiveHighlight highlight;

  /// True for an inbound-after-make beat -- the receiving screen should
  /// position this blip behind the *opposing* team's basket (the one
  /// just scored on), same rule `live_game_lab_screen.dart`'s own
  /// `_LabBeat.isInbound` documents, ignoring [zone]/[chipIndex] for
  /// placement.
  final bool isInbound;

  final bool isPass;
  final LiveZone? passFromZone;
  final int? passFromChipIndex;

  final bool isShotAttempt;
  final bool? shotMade;

  /// Routine free throws are the *caller's* call on whether to actually
  /// show this beat (the Lab's own "hidden unless clutch" rule is a
  /// screen-level policy, not baked into the translator) -- this just
  /// flags that it is one.
  final bool isFreeThrow;

  final int deltaHome;
  final int deltaAway;
  final double clockSeconds;
  final int quarter;

  LiveTeam get badgeTeam => creditTeam ?? team ?? LiveTeam.home;
}

/// Turns a real game's [MatchEvent]s (via [LiveGameSegment], from
/// `simulateMatchLive`) into [LiveBeat]s, resolving each one against
/// `play_by_play_phrases.toml`'s wording bank -- the real-game analog of
/// `live_game_lab_screen.dart`'s hand-authored `_beats` script
/// (2026-08-18, `TODO.md` item 8's live-game architecture stage 3).
///
/// Stateful by design -- construct one per live game and feed it every
/// [LiveGameSegment] `simulateMatchLive` produces, in order, via
/// [translateSegment]. It tracks the running clock/score/quarter and the
/// ball's last-known court position across calls, none of which a single
/// segment (or a single event) carries enough context to know on its
/// own.
///
/// **Zone/chip-index placement is a heuristic, not derived from real
/// court geometry** -- unlike the Lab's own 3pt-line/free-throw-line
/// fixes (which mirror `_FullCourtPainter`'s actual measurements),
/// [MatchEvent] carries no position data at all
/// (`possession_engine.dart`'s own doc comment: "There's no court-position
/// model yet"). Good enough for a first real pass; worth revisiting once
/// there's a live screen to actually watch it in.
class LiveBeatTranslator {
  LiveBeatTranslator({
    required this.homeRoster,
    required this.awayRoster,
    required this.homeAbbreviation,
    required this.awayAbbreviation,
  });

  final List<Player> homeRoster;
  final List<Player> awayRoster;
  final String homeAbbreviation;
  final String awayAbbreviation;

  final _random = math.Random();

  // Mirrors match_engine.dart's own private constants -- can't import
  // them directly (Dart privacy is file-scoped), and they're stable,
  // well-known WNBA constants unlikely to drift silently out of sync.
  static const _quarterSeconds = 600.0;
  static const _overtimeSeconds = 300.0;
  static const _quarterCount = 4;

  var _lastQuarter = 0;
  var _clockSeconds = 0.0;
  var _homeScore = 0;
  var _awayScore = 0;

  /// Whether the *next* possession's first pass should read as an inbound
  /// -- set at the end of [_translatePossession] based on how the
  /// possession that just finished ended. `false` for the very first
  /// possession of the game (the tip-off already establishes who has it,
  /// no inbound needed).
  var _nextPossessionIsInbound = false;

  /// Whether the game is currently "clutch" -- under a minute on the
  /// clock, score within 3 -- mirroring `live_game_lab_screen.dart`'s own
  /// `_isClutchFreeThrow` rule. The translator always returns a beat for
  /// every free throw ([LiveBeat.isFreeThrow]'s own doc comment); a
  /// screen wanting that same hide-unless-clutch policy checks this
  /// *before* deciding whether to actually show a given free-throw beat.
  /// `_lastQuarter > 0` guards the state before [translateSegment] has
  /// ever run -- without it, the untouched 0.0 starting clock would
  /// misread as "under a minute left" before the game even begins.
  bool get isClutch =>
      _lastQuarter > 0 &&
      _clockSeconds < 60 &&
      (_homeScore - _awayScore).abs() <= 3;

  /// Translates every possession in [segment], in order, updating the
  /// running clock/score/quarter as it goes. Call once per
  /// `simulateMatchLive` `onSegmentComplete` invocation, in the order
  /// they arrive -- this class has no way to make sense of segments fed
  /// out of order or skipped.
  List<LiveBeat> translateSegment(LiveGameSegment segment) {
    if (segment.quarter != _lastQuarter) {
      _lastQuarter = segment.quarter;
      _clockSeconds = segment.quarter <= _quarterCount
          ? _quarterSeconds
          : _overtimeSeconds;
      // Whoever starts a new quarter is decided independently
      // (`match_engine.dart`'s `startQuarterClock`: tip-off winner and
      // quarter parity, not "whoever didn't have the ball last") -- not
      // guaranteed to be the *other* team from however the previous
      // quarter happened to end. A real bug this exact mismatch caused
      // (caught by this file's own test suite): carrying the inbound
      // flag across a quarter break could credit the *same* team that
      // just scored to end the old quarter with "inbounding" to start
      // the new one, when the engine gave them the ball again by
      // independent coincidence, not a stolen/incorrect possession.
      _nextPossessionIsInbound = false;
    }
    final beats = <LiveBeat>[];
    for (final possession in segment.possessions) {
      beats.addAll(_translatePossession(possession));
    }
    return beats;
  }

  bool _isHome(Player player) => homeRoster.contains(player);

  String _abbreviationFor(Player player) =>
      _isHome(player) ? homeAbbreviation : awayAbbreviation;

  String _tag(Player player) {
    final number = player.jerseyNumber;
    final numberLabel = number == null ? '#--' : '#$number';
    return '$numberLabel ${player.name} '
        '(${player.primaryPosition.abbreviation} ${_abbreviationFor(player)})';
  }

  /// A vertical spread (0-4) within whichever zone a beat lands in --
  /// there's no real position data to derive this from (see this class's
  /// own doc comment), so this is arbitrary either way; genuinely random
  /// per beat, not keyed off the player, so the same player doesn't
  /// always land in the exact same spot on the floor every time she
  /// touches the ball. Was `player.id.hashCode.abs() % 5` (2026-08-18, a
  /// direct GM catch): a real, felt bug -- "the ball moving from A -> B
  /// -> C in the exact same spots on the floor every time a team has
  /// offense" -- because a fixed per-player hash meant every single beat
  /// a given player was ever involved in reused her one assigned slot,
  /// game after game, possession after possession.
  int _chipIndexFor(Player player) => _random.nextInt(5);

  String _phrase(
    String category, {
    required String playerTag,
    String? player2Tag,
    String? team,
    String? opponent,
  }) {
    final options = kPlayByPlayPhrases[category]!;
    final template = options[_random.nextInt(options.length)];
    var text = template.replaceAll('{player}', playerTag);
    if (player2Tag != null) text = text.replaceAll('{player2}', player2Tag);
    if (team != null) text = text.replaceAll('{team}', team);
    if (opponent != null) text = text.replaceAll('{opponent}', opponent);
    return text;
  }

  /// Whether the [shotMade] event at [index] was scored through contact
  /// -- and-one detection. `possession_engine.dart` always emits a made
  /// shot's `shootingFoul` either immediately after it or one slot later
  /// (an intervening `assist`), so checking the next 2 events is exact
  /// for this engine's own event ordering, not a loose guess.
  bool _isAndOne(List<MatchEvent> events, int index) {
    for (var j = index + 1; j < events.length && j <= index + 2; j++) {
      if (events[j].type == MatchEventType.shootingFoul) return true;
    }
    return false;
  }

  List<LiveBeat> _translatePossession(List<MatchEvent> events) {
    final beats = <LiveBeat>[];
    // The ball's own last-known court spot -- reset at the start of every
    // possession (a fresh possession always starts with someone bringing
    // it up, roughly at midcourt) and updated as passes/shots move it.
    var ballZone = LiveZone.midcourt;
    int? ballChipIndex;
    var sawFirstPass = false;
    // This possession's own first pass reads as an inbound (behind the
    // *other* team's basket -- the one just scored on) if the *previous*
    // possession ended in a made basket -- a direct GM catch (2026-08-18):
    // watching a real game, a make immediately followed by the other team
    // just "bringing it up" again read as if the scoring team still had
    // the ball, since nothing on screen marked the change of possession.
    // `_endsInMake` resets this for whichever possession comes next.
    final isInboundPossession = _nextPossessionIsInbound;
    _nextPossessionIsInbound = _endsInMake(events);

    // Held when the shot just translated turns out to be a made basket
    // immediately followed by its own assist (`possession_engine.dart`
    // always records it in exactly that order, for its own box-score
    // reducer's sake) -- appended right after the assist beat instead of
    // before it, so the pass that actually set up the score narrates
    // first. A real bug, live on-device, seen twice (2026-08-19, a direct
    // GM report): "1. Bkn scores a 2  2. Bkn player passes to the scorer
    // 3. WIC inbounds. So I think #2 was the assist, and it was just out
    // of order." Every bit of bookkeeping below (clock, zone tracking,
    // score) still runs in `events`' own real order regardless -- this
    // only reorders which beat gets appended to the *display* list first.
    LiveBeat? pendingShotBeat;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      _clockSeconds = math.max(0, _clockSeconds - event.secondsElapsed);
      final beat = _translateEvent(
        event,
        events,
        i,
        isFirstPassOfPossession:
            !sawFirstPass && event.type == MatchEventType.passAttempt,
        isInboundPossession: isInboundPossession,
        ballZone: ballZone,
        ballChipIndex: ballChipIndex,
      );
      if (event.type == MatchEventType.passAttempt) sawFirstPass = true;
      if (beat == null) continue;
      if (beat.zone != null) {
        ballZone = beat.zone!;
        ballChipIndex = beat.chipIndex;
      }
      if (beat.deltaHome != 0) _homeScore += beat.deltaHome;
      if (beat.deltaAway != 0) _awayScore += beat.deltaAway;

      final assistFollows =
          event.type == MatchEventType.shotMade &&
          i + 1 < events.length &&
          events[i + 1].type == MatchEventType.assist;
      if (assistFollows) {
        pendingShotBeat = beat;
        continue;
      }
      if (event.type == MatchEventType.assist && pendingShotBeat != null) {
        beats.add(beat);
        beats.add(pendingShotBeat);
        pendingShotBeat = null;
        continue;
      }
      beats.add(beat);
    }
    return beats;
  }

  /// Whether [events] -- one whole possession -- actually ended with the
  /// ball going through the hoop, i.e. the *next* possession's team will
  /// need to inbound rather than just pick up a loose/rebounded ball
  /// already live in play. Checks the *last* event (or the 2nd-to-last,
  /// when the very last is an [MatchEventType.assist] trailing an
  /// unfouled make -- `possession_engine.dart` always appends a scoring
  /// assist right after its `shotMade`, with nothing else following) --
  /// not whether a [MatchEventType.shotMade] appears *anywhere* in the
  /// list, a real bug caught by this file's own test suite: an and-one's
  /// free throws always end the possession outright in this engine
  /// (`_shootFreeThrows`'s own caller calls `finish` unconditionally right
  /// after), but a *missed* final free throw doesn't convert anything --
  /// the earlier made field goal in the same list doesn't mean the
  /// possession actually ended in a score. A missed final free throw is
  /// deliberately not treated as ending in a make either, for the same
  /// reason (its rebound is a genuinely live, not dead, ball).
  bool _endsInMake(List<MatchEvent> events) {
    if (events.isEmpty) return false;
    final last = events.last.type;
    if (last == MatchEventType.shotMade ||
        last == MatchEventType.freeThrowMade) {
      return true;
    }
    return last == MatchEventType.assist &&
        events.length >= 2 &&
        events[events.length - 2].type == MatchEventType.shotMade;
  }

  LiveBeat? _translateEvent(
    MatchEvent event,
    List<MatchEvent> possessionEvents,
    int index, {
    required bool isFirstPassOfPossession,
    required bool isInboundPossession,
    required LiveZone ballZone,
    int? ballChipIndex,
  }) {
    switch (event.type) {
      case MatchEventType.tipOff:
        final winner = event.player!;
        return LiveBeat(
          team: _isHome(winner) ? LiveTeam.home : LiveTeam.away,
          zone: LiveZone.centerCourt,
          displayText: _phrase(
            'tip_off',
            playerTag: _tag(winner),
            team: _abbreviationFor(winner),
          ),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.passAttempt:
        final passer = event.player!;
        final receiver = event.secondPlayer!;
        final team = _isHome(passer) ? LiveTeam.home : LiveTeam.away;
        final toChipIndex = _chipIndexFor(receiver);
        // The first pass of a possession reads as bringing the ball up
        // (a real distinction this engine's own possession structure
        // gives us for free -- not invented filler); later ones read as
        // generic ball movement. A direct GM ask (2026-08-18) about a
        // PG "setting up the offense" specifically wanted this read as
        // near mid-court, not hugging the 3pt line -- see LiveZone's own
        // `midcourt` case. When the *previous* possession ended in a
        // make, this specific first pass is an inbound instead -- its own
        // wording and blip placement (behind the opposing basket, via
        // `isInbound`), so the change of possession after a bucket is
        // unmistakable rather than reading as the scoring team still
        // holding the ball (2026-08-18, a direct GM catch).
        final isInboundPass = isFirstPassOfPossession && isInboundPossession;
        // Every pass *after* the bring-up used to land at that exact same
        // fixed near-center spot too, no matter how many more times the
        // ball moved that possession -- a direct GM catch (2026-08-19):
        // "still have minor complaints about the location of passes...
        // really focused in one little area, all near the circle in
        // center-court... The most likely place for just passing around
        // to find an opening is around the 3pt perimeter line, and then
        // even back a little bit towards mid-court." None of these are
        // ever the scoring pass itself -- an assist gets its own beat,
        // positioned at the shot -- so there's no accuracy to protect
        // here, just spreading the "team's probing for an opening" beats
        // across the same range the offense actually spaces out into.
        // `chipIndex` (already random) covers top/bottom/center on its
        // own at either zone.
        final laterPassZone = _random.nextDouble() < 0.7
            ? LiveZone.threePoint
            : LiveZone.midcourt;
        final displayText = isInboundPass
            ? _phrase(
                'inbound_after_make',
                playerTag: _tag(passer),
                player2Tag: _tag(receiver),
                team: _abbreviationFor(passer),
                opponent: _isHome(passer) ? awayAbbreviation : homeAbbreviation,
              )
            : (isFirstPassOfPossession
                  ? _phrase('backcourt_bringup', playerTag: _tag(passer))
                  : _phrase(
                      'midcourt_advance',
                      playerTag: _tag(passer),
                      player2Tag: _tag(receiver),
                    ));
        return LiveBeat(
          team: team,
          zone: isFirstPassOfPossession ? LiveZone.midcourt : laterPassZone,
          chipIndex: toChipIndex,
          displayText: displayText,
          isInbound: isInboundPass,
          isPass: !isFirstPassOfPossession,
          passFromZone: isFirstPassOfPossession ? null : ballZone,
          passFromChipIndex: isFirstPassOfPossession ? null : ballChipIndex,
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.steal:
        final stealer = event.player!;
        final victim = event.secondPlayer!;
        return LiveBeat(
          team: _isHome(victim) ? LiveTeam.home : LiveTeam.away,
          creditTeam: _isHome(stealer) ? LiveTeam.home : LiveTeam.away,
          zone: LiveZone.midcourt,
          chipIndex: _chipIndexFor(stealer),
          highlight: LiveHighlight.steal,
          displayText: _phrase(
            'steal',
            playerTag: _tag(stealer),
            player2Tag: _tag(victim),
          ),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.shotAttempt:
        // The attempt itself carries no outcome yet -- shotMade/
        // shotMissed (below) is where the actual beat comes from, same
        // as this engine's own box-score reducer treats it. No beat
        // here avoids a redundant "X takes a shot" line immediately
        // followed by "X makes/misses it."
        return null;

      case MatchEventType.shotMade:
        {
          final shooter = event.player!;
          final isThree = event.isThreePointAttempt ?? false;
          final andOne = _isAndOne(possessionEvents, index);
          final category = andOne
              ? 'and_one'
              : (isThree ? 'threept_make' : 'twopt_make');
          final isHome = _isHome(shooter);
          return LiveBeat(
            team: isHome ? LiveTeam.home : LiveTeam.away,
            zone: isThree ? LiveZone.threePoint : LiveZone.paint,
            chipIndex: _chipIndexFor(shooter),
            highlight: andOne
                ? LiveHighlight.andOne
                : (isThree
                      ? LiveHighlight.threePointer
                      : LiveHighlight.twoPointer),
            isShotAttempt: true,
            shotMade: true,
            deltaHome: isHome ? (event.points ?? 0) : 0,
            deltaAway: isHome ? 0 : (event.points ?? 0),
            displayText: _phrase(category, playerTag: _tag(shooter)),
            clockSeconds: _clockSeconds,
            quarter: _lastQuarter,
          );
        }

      case MatchEventType.shotMissed:
        {
          final shooter = event.player!;
          final isThree = event.isThreePointAttempt ?? false;
          return LiveBeat(
            team: _isHome(shooter) ? LiveTeam.home : LiveTeam.away,
            zone: isThree ? LiveZone.threePoint : LiveZone.paint,
            chipIndex: _chipIndexFor(shooter),
            isShotAttempt: true,
            shotMade: false,
            displayText: _phrase(
              isThree ? 'threept_miss' : 'twopt_miss',
              playerTag: _tag(shooter),
            ),
            clockSeconds: _clockSeconds,
            quarter: _lastQuarter,
          );
        }

      case MatchEventType.shotBlocked:
        final blocker = event.player!;
        final shooter = event.secondPlayer!;
        return LiveBeat(
          team: _isHome(shooter) ? LiveTeam.home : LiveTeam.away,
          creditTeam: _isHome(blocker) ? LiveTeam.home : LiveTeam.away,
          zone: LiveZone.paint,
          chipIndex: _chipIndexFor(shooter),
          highlight: LiveHighlight.block,
          displayText: _phrase('block', playerTag: _tag(blocker)),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.assist:
        final passer = event.player!;
        final scorer = event.secondPlayer!;
        return LiveBeat(
          team: _isHome(passer) ? LiveTeam.home : LiveTeam.away,
          zone: ballZone,
          chipIndex: ballChipIndex,
          displayText: _phrase(
            'assist',
            playerTag: _tag(passer),
            player2Tag: _tag(scorer),
          ),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.offensiveRebound:
        {
          final rebounder = event.player!;
          // A putback (this same beat immediately followed by a made
          // shot from the same rebounder) gets the more specific
          // category; a plain offensive board otherwise.
          final isPutback =
              index + 1 < possessionEvents.length &&
              possessionEvents[index + 1].type == MatchEventType.shotMade &&
              possessionEvents[index + 1].player == rebounder;
          return LiveBeat(
            team: _isHome(rebounder) ? LiveTeam.home : LiveTeam.away,
            zone: LiveZone.paint,
            chipIndex: _chipIndexFor(rebounder),
            displayText: _phrase(
              isPutback ? 'putback' : 'offensive_rebound',
              playerTag: _tag(rebounder),
            ),
            clockSeconds: _clockSeconds,
            quarter: _lastQuarter,
          );
        }

      case MatchEventType.defensiveRebound:
        {
          final rebounder = event.player!;
          final rebounderIsHome = _isHome(rebounder);
          // The rebound itself happens where the miss just came down --
          // the *shooting* team's own attacking end, not the rebounding
          // (defensive) team's -- so `team` (the position [_blipAlignment]
          // reads) is the opposite side from the rebounder, same
          // credit-vs-position split [MatchEventType.shotBlocked] already
          // uses. A real bug, live on-device (2026-08-19, a direct GM
          // report): "WIC just shot and missed, so it's on the right side
          // (WIC is home)... there's a defensive rebound by MTY. BUT the
          // blip for the defensive rebound is on the left side. Defensive
          // rebound should be on the right side, where the shot just
          // bounced off the rim" -- this used to key position off the
          // rebounder's own team, putting it at *their* attacking end
          // (the wrong basket) instead of the shooter's.
          return LiveBeat(
            team: rebounderIsHome ? LiveTeam.away : LiveTeam.home,
            creditTeam: rebounderIsHome ? LiveTeam.home : LiveTeam.away,
            zone: LiveZone.paint,
            chipIndex: _chipIndexFor(rebounder),
            displayText: _phrase(
              'defensive_rebound',
              playerTag: _tag(rebounder),
              team: _abbreviationFor(rebounder),
            ),
            clockSeconds: _clockSeconds,
            quarter: _lastQuarter,
          );
        }

      case MatchEventType.shotClockViolation:
        final player = event.player!;
        return LiveBeat(
          team: _isHome(player) ? LiveTeam.home : LiveTeam.away,
          zone: LiveZone.midcourt,
          chipIndex: _chipIndexFor(player),
          displayText: _phrase(
            'shot_clock_violation',
            playerTag: _tag(player),
            team: _abbreviationFor(player),
          ),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.shootingFoul:
        {
          // Already folded into the preceding shotMade's `and_one`
          // phrasing when the shot went in -- only needs its own beat
          // when the shot *missed* (a foul with no basket, free throws
          // to follow).
          final precedingMade =
              index > 0 &&
              possessionEvents[index - 1].type == MatchEventType.shotMade;
          final assistThenMade =
              index > 1 &&
              possessionEvents[index - 1].type == MatchEventType.assist &&
              possessionEvents[index - 2].type == MatchEventType.shotMade;
          if (precedingMade || assistThenMade) return null;
          final shooter = event.secondPlayer!;
          final defender = event.player!;
          return LiveBeat(
            team: _isHome(shooter) ? LiveTeam.home : LiveTeam.away,
            creditTeam: _isHome(defender) ? LiveTeam.home : LiveTeam.away,
            zone: LiveZone.paint,
            chipIndex: _chipIndexFor(shooter),
            displayText: _phrase(
              'shooting_foul_no_make',
              playerTag: _tag(shooter),
              player2Tag: _tag(defender),
            ),
            clockSeconds: _clockSeconds,
            quarter: _lastQuarter,
          );
        }

      case MatchEventType.nonShootingFoul:
        final defender = event.player!;
        return LiveBeat(
          team: _isHome(defender) ? LiveTeam.away : LiveTeam.home,
          creditTeam: _isHome(defender) ? LiveTeam.home : LiveTeam.away,
          zone: LiveZone.midcourt,
          chipIndex: _chipIndexFor(defender),
          displayText: _phrase(
            'foul_no_ft',
            playerTag: _tag(defender),
            team: _abbreviationFor(defender),
          ),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      case MatchEventType.freeThrowMade:
        {
          final shooter = event.player!;
          final isHome = _isHome(shooter);
          return LiveBeat(
            team: isHome ? LiveTeam.home : LiveTeam.away,
            zone: LiveZone.freeThrowLine,
            isFreeThrow: true,
            deltaHome: isHome ? 1 : 0,
            deltaAway: isHome ? 0 : 1,
            displayText: _phrase('free_throws', playerTag: _tag(shooter)),
            clockSeconds: _clockSeconds,
            quarter: _lastQuarter,
          );
        }

      case MatchEventType.freeThrowMissed:
        final shooter = event.player!;
        return LiveBeat(
          team: _isHome(shooter) ? LiveTeam.home : LiveTeam.away,
          zone: LiveZone.freeThrowLine,
          isFreeThrow: true,
          displayText: _phrase('free_throws', playerTag: _tag(shooter)),
          clockSeconds: _clockSeconds,
          quarter: _lastQuarter,
        );

      // Intermediate/transitional events with no distinct narration of
      // their own -- each is always immediately followed by the event
      // that actually resolves what happened (a steal, a foul, an
      // out-of-bounds turnover), which gets its own beat above. Showing
      // both would just be two beats for one real moment.
      case MatchEventType.passDisrupted:
      case MatchEventType.passRedirected:
      case MatchEventType.passOutOfBounds:
        return null;
    }
  }
}
