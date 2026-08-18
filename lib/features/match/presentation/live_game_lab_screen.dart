import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/onboarding/quick_start_teams.dart';
import '../../matchup/domain/coaching_option.dart';
import 'play_by_play_phrases.dart';

/// Which team (if any) a [_LabBeat] belongs to -- `null` for a neutral
/// beat like the opening tip-off.
enum _Team { home, away }

/// Which zone (if any) a [_LabBeat]'s action happened in -- drives where
/// a blip lands. `null` for a beat with no blip at all (team-level
/// flavor). Split out of a single flat `arc` zone (2026-08-18, a direct
/// GM catch): "not all of the 3 pointers are coming in from outside the
/// 3pt arc" -- a single magnitude tuned for one perimeter position
/// landed inside the drawn line at another, and separately, general
/// perimeter ball-handling ("the PG calling up a play") needed to read
/// as "near the halfway mark," not hugging the 3pt line itself. See
/// [_FullCourtPanel._blipAlignment] for exactly where each one lands.
enum _Zone {
  paint,

  /// Deep midcourt/backcourt ball-handling -- bringing it up, clock
  /// milking, a steal in the open floor. Reads as "near halfcourt, this
  /// team's offensive side," not tied to the 3pt line's actual geometry.
  midcourt,

  /// An actual three-point attempt -- positioned via
  /// [_FullCourtPanel._threePointBlipMagnitude], which mirrors
  /// `_FullCourtPainter`'s own real measurements so the blip always
  /// lands safely beyond the drawn arc, at every chip position.
  threePoint,

  /// The free-throw line specifically -- a direct GM ask (2026-08-18):
  /// "if you're gonna call foul shots, there should be a blip at the
  /// appropriate foul line."
  freeThrowLine,

  /// Center court -- the tip-off's own spot, and nothing else.
  centerCourt,
}

/// Playback speed for the scripted beat sequence -- a `SegmentedButton`
/// picker (2026-08-17, a direct GM ask), same pattern the Settings theme
/// picker already uses. Intervals slid slower on a same-session
/// follow-up ask ("let's slide those speed a little") -- the first pass
/// (1.8s/1.1s/0.55s) read as too fast to actually read a play. [step]
/// added on a later follow-up ask ("one play at a time... the user has
/// to click to see the next play") -- no auto-timer at all in that mode,
/// see [_LiveGameLabScreenState._stepOnce].
enum _Speed { slow, medium, fast, step }

/// Only meaningful for the 3 auto-advancing speeds -- [_Speed.step] has
/// no timer, but still needs *some* value here since ball-travel
/// animation durations scale off it regardless of mode (falls back to
/// the medium pace).
int _intervalMsFor(_Speed speed) => switch (speed) {
  _Speed.slow => 3000,
  _Speed.medium => 2000,
  _Speed.fast => 750,
  _Speed.step => 2000,
};

/// A notable play worth calling out with a colored keyword badge --
/// "keywords that stand out" (2026-08-17, a direct GM ask). Every made
/// basket gets one now (`twoPointer` added in the same-session follow-up
/// on assists/shots: "I think Bold is reserved for steals and buckets,
/// and blocks") -- a pass/assist beat is deliberately *not* one of
/// these, see [_LabBeat.isPass]'s own doc comment for why that's a
/// separate, plain-text treatment instead.
enum _Highlight { none, twoPointer, threePointer, andOne, steal, block }

extension on _Highlight {
  String? get label => switch (this) {
    _Highlight.none => null,
    _Highlight.twoPointer => '2PTS',
    _Highlight.threePointer => '3PTS',
    _Highlight.andOne => 'AND-1',
    _Highlight.steal => 'STEAL',
    _Highlight.block => 'BLOCK',
  };
}

/// Every category in `play_by_play_phrases.toml` (via the generated
/// `play_by_play_phrases.dart`) -- one entry per `[section]` header.
/// [tomlKey] is the bridge back to that file's `Map` keys; see
/// `tool/generate_play_by_play_phrases.py` for how the TOML becomes that
/// map.
enum _PhraseCategory {
  tipOff,
  inboundAfterMake,
  inboundAfterDeadball,
  backcourtBringup,
  midcourtAdvance,
  perimeterNoName,
  clockMilking,
  foulNoFt,
  twoPointMake,
  twoPointMiss,
  threePointMake,
  threePointMiss,
  andOne,
  freeThrows,
  putback,
  block,
  steal,
  defensiveRebound,
  assist,
}

extension on _PhraseCategory {
  String get tomlKey => switch (this) {
    _PhraseCategory.tipOff => 'tip_off',
    _PhraseCategory.inboundAfterMake => 'inbound_after_make',
    _PhraseCategory.inboundAfterDeadball => 'inbound_after_deadball',
    _PhraseCategory.backcourtBringup => 'backcourt_bringup',
    _PhraseCategory.midcourtAdvance => 'midcourt_advance',
    _PhraseCategory.perimeterNoName => 'perimeter_no_name',
    _PhraseCategory.clockMilking => 'clock_milking',
    _PhraseCategory.foulNoFt => 'foul_no_ft',
    _PhraseCategory.twoPointMake => 'twopt_make',
    _PhraseCategory.twoPointMiss => 'twopt_miss',
    _PhraseCategory.threePointMake => 'threept_make',
    _PhraseCategory.threePointMiss => 'threept_miss',
    _PhraseCategory.andOne => 'and_one',
    _PhraseCategory.freeThrows => 'free_throws',
    _PhraseCategory.putback => 'putback',
    _PhraseCategory.block => 'block',
    _PhraseCategory.steal => 'steal',
    _PhraseCategory.defensiveRebound => 'defensive_rebound',
    _PhraseCategory.assist => 'assist',
  };
}

final _phraseRandom = math.Random();

/// "#4 Castellano (PG DSM)" -- the same tag format the old hardcoded
/// `displayText` used to build itself; now built once per player
/// reference wherever a phrase template needs a `{player}`/`{player2}`.
String _tag(String name, int number, String position, String team) =>
    '#$number $name ($position $team)';

/// Picks a random phrase from [category]'s bank and fills in its
/// placeholders -- see the header comment in `play_by_play_phrases.toml`
/// for the full placeholder contract. Called once per beat, at
/// `_beats`-list-construction time (not per rebuild), so a beat's wording
/// is picked fresh each time the lab reloads but stays stable for the
/// rest of that session.
String _phrase(
  _PhraseCategory category, {
  String? playerTag,
  String? player2Tag,
  String? team,
  String? opponent,
}) {
  final options = kPlayByPlayPhrases[category.tomlKey]!;
  final template = options[_phraseRandom.nextInt(options.length)];
  var text = template;
  if (playerTag != null) text = text.replaceAll('{player}', playerTag);
  if (player2Tag != null) text = text.replaceAll('{player2}', player2Tag);
  if (team != null) text = text.replaceAll('{team}', team);
  if (opponent != null) text = text.replaceAll('{opponent}', opponent);
  return text;
}

/// One scripted beat in the mock possession sequence -- hand-picked
/// *categories* resolved to actual wording via [_phrase] against
/// `play_by_play_phrases.toml`'s content bank, not real engine output,
/// so pacing/structure can be tuned directly rather than filtered out of
/// a much noisier real `MatchEvent` log. Wiring this to a real
/// `simulateMatch` result is a natural follow-up once the visual itself
/// is settled.
class _LabBeat {
  const _LabBeat({
    required this.team,
    this.zone,
    this.chipIndex,
    this.creditTeam,
    required this.action,
    this.highlight = _Highlight.none,
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
    this.isBreak = false,
    this.breakLabel,
  });

  /// Whose attacking end this happened at -- drives the blip's
  /// left/right position.
  final _Team? team;
  final _Zone? zone;

  /// Which of 5 candidate slots within a zone the blip spawns at -- for
  /// a pass beat, this is the *receiver's* spot (where the ball ends
  /// up); for a shot beat, the shooter's spot the ball travels to the
  /// basket from.
  final int? chipIndex;

  /// Who gets credit for this beat -- the badge, the blip's color, and
  /// the "(POS TEAM)" tag all read off this. Defaults to [team]; only
  /// ever overridden for a defensive highlight (a block/steal), where
  /// the play still happens at the *offense's* end ([team]) but the
  /// credited player is on the other side -- see [badgeTeam].
  final _Team? creditTeam;

  /// The fully-resolved play-by-play sentence -- built once, at
  /// `_beats`-construction time, via [_phrase] against a
  /// `play_by_play_phrases.toml` category. Already contains any
  /// `{player}`/`{player2}`/`{team}`/`{opponent}` tags filled in, so
  /// [displayText] below no longer needs to prepend anything.
  final String action;
  final _Highlight highlight;

  /// True for an inbound beat -- overrides the blip's position entirely
  /// to sit right behind the *opposing* team's basket, ignoring [zone]/
  /// [chipIndex] for placement (see [_FullCourtPanel]'s blip-positioning
  /// logic). A direct GM catch (2026-08-18): "I can't tell where the
  /// check-ins are coming from... it should be from behind their own
  /// basket. Ie, the same basket that the opposing team just scored on."
  /// [team] here is still the *inbounding* team (the one now taking it
  /// out) -- their own basket is the opponent's attacking end, which is
  /// exactly where the ball physically is after a made shot.
  final bool isInbound;

  /// True for an assist's pass half -- a direct GM ask (2026-08-17):
  /// "I think Bold is reserved for steals and buckets, and blocks," so a
  /// pass gets the same "TEAM Label" headline shape as a highlight but
  /// deliberately un-bold, plain text -- see [_PlayHeadline]. Also
  /// drives the ball-travel animation from [passFromZone]/
  /// [passFromChipIndex] (the passer's spot) to [zone]/[chipIndex] (the
  /// receiver's spot) -- see [_FullCourtPanel].
  final bool isPass;
  final _Zone? passFromZone;
  final int? passFromChipIndex;

  /// True for a field-goal attempt (make or miss) -- drives the
  /// ball-travel animation from [zone]/[chipIndex] (the shooter's spot)
  /// to the shooting team's basket, then a flash/float result popup
  /// (points made, or a red miss mark) once the ball arrives. [shotMade]
  /// is only meaningful when this is true. Blocks/steals/fouls/rebounds
  /// don't get this treatment -- their own badge already carries the
  /// moment.
  final bool isShotAttempt;
  final bool? shotMade;

  /// Routine free throws don't get shown at all by default -- a direct
  /// GM ask (2026-08-17): "generally, I don't want to see free throws.
  /// But... if it's under a minute, and the game is within 3 points, I'd
  /// like to see them." Still applied to the score either way; only
  /// whether this beat ever becomes `current` (and so visible) is
  /// conditional -- see `_LiveGameLabScreenState._step`'s clutch check.
  final bool isFreeThrow;

  final int deltaHome;
  final int deltaAway;
  final int clockSeconds;
  final bool isBreak;
  final String? breakLabel;

  _Team get badgeTeam => creditTeam ?? team ?? _Team.home;

  /// "#4 Castellano (PG DSM) drives and scores." -- a direct GM ask
  /// (2026-08-17): "when naming a player, instead of 'Castellano drives
  /// and scores', it should be like '#42 Castellano (PF DSM) drives and
  /// scores.'" Now just [action] verbatim -- the phrase templates
  /// themselves place the `{player}` tag (a later GM ask, same date:
  /// "every phrase is a complete sentence template," since some phrasing
  /// puts the tag mid-sentence or uses two tags).
  String get displayText => action;
}

/// Des Moines Dragons (home) vs. Kansas City Aviators (away) -- 2 of the
/// app's real Quick Start club identities (`quick_start_teams.dart`),
/// not invented placeholder teams, so the colors/names/emoji here are
/// authentic to what a GM would actually see.
const _homeTeam = kQuickStartDesMoinesDragons;
const _awayTeam = kQuickStartKansasCityAviators;
final _homeEmoji = _homeTeam.emoji;
final _homeColor = _colorFromHex(_homeTeam.colors.primaryHex);
final _awayColor = _colorFromHex(_awayTeam.colors.primaryHex);

Color _colorFromHex(String hex) {
  final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | value);
}

/// A team color, nudged toward a minimum (dark mode) or maximum (light
/// mode) lightness so it stays legible as *text* against the page
/// background -- the exact problem the dark/light toggle above exists to
/// catch (2026-08-17, a direct GM concern): "some team colors won't be
/// readable, depending on dark mode vs light mode. In light mode, a
/// lime green isn't readable, in dark mode, a dark red won't be
/// readable." DSM's own dark green is a real example of this -- fine as
/// a badge *background* (`_HighlightBadge` computes its own contrasting
/// text color there), but unreadable as plain text on the dark navy
/// scorebug until this nudge.
Color _legibleTextColor(Color raw, Brightness brightness) {
  final hsl = HSLColor.fromColor(raw);
  final lightness = brightness == Brightness.dark
      ? math.max(hsl.lightness, 0.62)
      : math.min(hsl.lightness, 0.42);
  return hsl.withLightness(lightness.clamp(0.0, 1.0)).toColor();
}

/// A small invented roster (last name, number, position) for each team
/// -- just enough identity to make the "#N Name (POS TEAM)" tag format
/// feel real, not a placeholder like "Player 1." Home's Center (needed
/// for the tip-off's positional rule below) is Whitfield -- previously
/// only a name mentioned in flavor text for the block beat, promoted to
/// a full roster spot once the tip-off actually needed a real Center to
/// credit.
///
/// Not `const` anymore -- each beat's `action` is resolved by [_phrase]
/// against the wording bank at list-construction time (a top-level
/// `final` still only runs this once per app session, same cost as the
/// old `const` literal in practice).
final _beats = <_LabBeat>[
  // Tip-off: must go to a Center (PF if the team has no Center) -- a
  // direct GM ask (2026-08-17): "a PG winning a tip-off ain't happening.
  // It's either the Center, or if they don't have a Center than it's a
  // PF." Home's roster has a Center (Whitfield), so no PF fallback
  // needed here.
  _LabBeat(
    // team is home here (not null) specifically so the tip-off gets a
    // real blip -- "on the tipoff, put a blip at center court" (a direct
    // GM ask, 2026-08-18). centerCourt ignores team/chipIndex for
    // positioning either way (`_FullCourtPanel._blipAlignment`), so this
    // only matters for the `zoned` filter and the blip's color.
    team: _Team.home,
    creditTeam: _Team.home,
    zone: _Zone.centerCourt,
    action: _phrase(
      _PhraseCategory.tipOff,
      playerTag: _tag('Whitfield', 0, 'C', _homeTeam.abbreviation),
      team: _homeTeam.abbreviation,
    ),
    clockSeconds: 600,
  ),
  // A filler beat -- no score, no highlight, just atmosphere. A direct
  // GM ask (2026-08-17): "some filler items every 3ish possessions...
  // having some dull items in here will make the exciting moments feel
  // MORE exciting." Sprinkled through the sequence, not batched.
  // Soft PG bias for "setting up a play" (2026-08-17, a direct GM ask) --
  // Castellano is DSM's PG.
  _LabBeat(
    team: _Team.home,
    zone: _Zone.midcourt,
    chipIndex: 2,
    action: _phrase(
      _PhraseCategory.backcourtBringup,
      playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation),
    ),
    clockSeconds: 594,
  ),
  // Team-level flavor, no player, no blip -- "sometimes a sequence
  // without even a player name where it just says that some team is
  // passing it around the perimeter" (2026-08-17, a direct GM ask).
  _LabBeat(
    team: _Team.home,
    action: _phrase(
      _PhraseCategory.perimeterNoName,
      team: _homeTeam.abbreviation,
    ),
    clockSeconds: 588,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 0,
    action: _phrase(
      _PhraseCategory.twoPointMake,
      playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation),
    ),
    highlight: _Highlight.twoPointer,
    isShotAttempt: true,
    shotMade: true,
    deltaHome: 2,
    clockSeconds: 580,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.threePoint,
    chipIndex: 4,
    action: _phrase(
      _PhraseCategory.threePointMake,
      playerTag: _tag('Chen', 8, 'SG', _awayTeam.abbreviation),
    ),
    highlight: _Highlight.threePointer,
    isShotAttempt: true,
    shotMade: true,
    deltaAway: 3,
    clockSeconds: 566,
  ),
  // Inbound after a made basket -- reserved for "a big play" (a three,
  // here), not fired after every score -- a direct GM ask (2026-08-17):
  // "inbounding doesn't need to be called EVERY time... definitely after
  // a big offensive play, so the game doesn't feel so stale." isInbound
  // (2026-08-18, a follow-up catch) puts the blip behind the *opposing*
  // team's basket -- the one KCY just scored on -- not wherever zone/
  // chipIndex would otherwise place it.
  _LabBeat(
    team: _Team.home,
    zone: _Zone.midcourt,
    isInbound: true,
    action: _phrase(
      _PhraseCategory.inboundAfterMake,
      playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation),
      team: _homeTeam.abbreviation,
      opponent: _awayTeam.abbreviation,
    ),
    clockSeconds: 560,
  ),
  _LabBeat(
    team: _Team.home,
    creditTeam: _Team.away,
    zone: _Zone.paint,
    chipIndex: 2,
    action: _phrase(
      _PhraseCategory.block,
      playerTag: _tag('Petrov', 55, 'C', _awayTeam.abbreviation),
    ),
    highlight: _Highlight.block,
    clockSeconds: 548,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.freeThrowLine,
    action: _phrase(
      _PhraseCategory.freeThrows,
      playerTag: _tag('Holloway', 14, 'SF', _awayTeam.abbreviation),
    ),
    isFreeThrow: true,
    deltaAway: 2,
    clockSeconds: 540,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 2,
    action: _phrase(
      _PhraseCategory.putback,
      playerTag: _tag('Okonkwo', 21, 'PF', _homeTeam.abbreviation),
    ),
    highlight: _Highlight.twoPointer,
    isShotAttempt: true,
    shotMade: true,
    deltaHome: 2,
    clockSeconds: 530,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.threePoint,
    chipIndex: 1,
    action: _phrase(
      _PhraseCategory.threePointMiss,
      playerTag: _tag('Tuiasosopo', 32, 'PF', _awayTeam.abbreviation),
    ),
    isShotAttempt: true,
    shotMade: false,
    clockSeconds: 515,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 0,
    action: _phrase(
      _PhraseCategory.andOne,
      playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation),
    ),
    highlight: _Highlight.andOne,
    isShotAttempt: true,
    shotMade: true,
    deltaHome: 3,
    clockSeconds: 502,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.paint,
    chipIndex: 2,
    action: _phrase(
      _PhraseCategory.twoPointMake,
      playerTag: _tag('Petrov', 55, 'C', _awayTeam.abbreviation),
    ),
    highlight: _Highlight.twoPointer,
    isShotAttempt: true,
    shotMade: true,
    deltaAway: 2,
    clockSeconds: 491,
  ),
  _LabBeat(
    team: _Team.away,
    creditTeam: _Team.home,
    zone: _Zone.midcourt,
    chipIndex: 1,
    action: _phrase(
      _PhraseCategory.steal,
      playerTag: _tag('Vasquez', 11, 'SG', _homeTeam.abbreviation),
      player2Tag: _tag('Reyes', 3, 'PG', _awayTeam.abbreviation),
    ),
    highlight: _Highlight.steal,
    clockSeconds: 478,
  ),
  // A dead-ball foul, not in the bonus -- credited to the defense.
  _LabBeat(
    team: _Team.home,
    creditTeam: _Team.away,
    zone: _Zone.paint,
    chipIndex: 1,
    action: _phrase(
      _PhraseCategory.foulNoFt,
      playerTag: _tag('Tuiasosopo', 32, 'PF', _awayTeam.abbreviation),
      team: _awayTeam.abbreviation,
    ),
    clockSeconds: 472,
  ),
  // ...and the resulting dead-ball inbound. Not a basket-anchored spot
  // like inboundAfterMake above -- a foul stoppage restarts wherever it
  // happened, not "behind a basket" -- so this stays a normal midcourt
  // position rather than using isInbound.
  _LabBeat(
    team: _Team.home,
    zone: _Zone.midcourt,
    chipIndex: 2,
    action: _phrase(
      _PhraseCategory.inboundAfterDeadball,
      playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation),
      team: _homeTeam.abbreviation,
    ),
    clockSeconds: 468,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.midcourt,
    chipIndex: 1,
    action: _phrase(
      _PhraseCategory.clockMilking,
      playerTag: _tag('Vasquez', 11, 'SG', _homeTeam.abbreviation),
      team: _homeTeam.abbreviation,
    ),
    clockSeconds: 461,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.threePoint,
    chipIndex: 4,
    passFromZone: _Zone.midcourt,
    passFromChipIndex: 2,
    isPass: true,
    action: _phrase(
      _PhraseCategory.assist,
      playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation),
      player2Tag: _tag('Marsh', 23, 'SF', _homeTeam.abbreviation),
    ),
    clockSeconds: 454,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.threePoint,
    chipIndex: 4,
    action: _phrase(
      _PhraseCategory.threePointMake,
      playerTag: _tag('Marsh', 23, 'SF', _homeTeam.abbreviation),
    ),
    highlight: _Highlight.threePointer,
    isShotAttempt: true,
    shotMade: true,
    deltaHome: 3,
    clockSeconds: 440,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.threePoint,
    chipIndex: 3,
    passFromZone: _Zone.midcourt,
    passFromChipIndex: 1,
    isPass: true,
    action: _phrase(
      _PhraseCategory.assist,
      playerTag: _tag('Reyes', 3, 'PG', _awayTeam.abbreviation),
      player2Tag: _tag('Chen', 8, 'SG', _awayTeam.abbreviation),
    ),
    clockSeconds: 425,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.threePoint,
    chipIndex: 3,
    action: _phrase(
      _PhraseCategory.threePointMake,
      playerTag: _tag('Chen', 8, 'SG', _awayTeam.abbreviation),
    ),
    highlight: _Highlight.threePointer,
    isShotAttempt: true,
    shotMade: true,
    deltaAway: 3,
    clockSeconds: 410,
  ),
  _LabBeat(
    team: _Team.home,
    action: _phrase(
      _PhraseCategory.perimeterNoName,
      team: _homeTeam.abbreviation,
    ),
    clockSeconds: 402,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 2,
    action: _phrase(
      _PhraseCategory.twoPointMake,
      playerTag: _tag('Okonkwo', 21, 'PF', _homeTeam.abbreviation),
    ),
    highlight: _Highlight.twoPointer,
    isShotAttempt: true,
    shotMade: true,
    deltaHome: 2,
    clockSeconds: 392,
  ),
  // Another filler pass -- "just noting a pass somewhere and showing the
  // animation... doesn't have to lead to anything" (2026-08-17, the same
  // GM ask). Uses the exact same isPass/ball-travel machinery an assist
  // does; the only difference is no shot beat follows it.
  _LabBeat(
    team: _Team.away,
    zone: _Zone.paint,
    chipIndex: 1,
    passFromZone: _Zone.midcourt,
    passFromChipIndex: 0,
    isPass: true,
    action: _phrase(
      _PhraseCategory.midcourtAdvance,
      playerTag: _tag('Reyes', 3, 'PG', _awayTeam.abbreviation),
      player2Tag: _tag('Tuiasosopo', 32, 'PF', _awayTeam.abbreviation),
    ),
    clockSeconds: 383,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.paint,
    chipIndex: 0,
    action: _phrase(
      _PhraseCategory.twoPointMiss,
      playerTag: _tag('Holloway', 14, 'SF', _awayTeam.abbreviation),
    ),
    isShotAttempt: true,
    shotMade: false,
    clockSeconds: 372,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 3,
    action: _phrase(
      _PhraseCategory.defensiveRebound,
      playerTag: _tag('Okonkwo', 21, 'PF', _homeTeam.abbreviation),
      team: _homeTeam.abbreviation,
    ),
    clockSeconds: 368,
  ),
  // Free throws stay hidden by default, but this one qualifies -- under
  // a minute, game within 3 -- so it'll actually show (see
  // `_LiveGameLabScreenState._step`'s clutch check).
  _LabBeat(
    team: _Team.away,
    zone: _Zone.freeThrowLine,
    action: _phrase(
      _PhraseCategory.freeThrows,
      playerTag: _tag('Petrov', 55, 'C', _awayTeam.abbreviation),
    ),
    isFreeThrow: true,
    deltaAway: 2,
    clockSeconds: 45,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.threePoint,
    chipIndex: 1,
    action:
        '${_phrase(_PhraseCategory.threePointMake, playerTag: _tag('Castellano', 4, 'PG', _homeTeam.abbreviation))} '
        'End of the quarter.',
    highlight: _Highlight.threePointer,
    isShotAttempt: true,
    shotMade: true,
    deltaHome: 3,
    clockSeconds: 0,
    isBreak: true,
    breakLabel: 'END OF Q1',
  ),
];

/// A dev-only lab (reachable from Settings -- "a direct GM ask,
/// 2026-08-17, following the stamina/fatigue system landing": "I want to
/// see it in the app," not a design mockup elsewhere) for the live-game
/// visual half of `TODO.md` item 8. Started as 3 side-by-side options;
/// narrowed to just the Full Court design once the GM settled on it
/// ("we can drop/hide Ticker and Half-Court... I'm going to keep working
/// with Full Court, it's the best") -- the other two panels' code was
/// removed outright rather than left dead/hidden, matching this repo's
/// usual "delete, don't comment out" convention.
///
/// The coaching-break sheet (2026-08-17: now the real, locked
/// [CoachingOption] catalog + [offerCoachingOptions] selection logic --
/// `0B_Planned.md`'s quarter-break bullet -- replacing the earlier
/// DefensiveTactic-re-pick placeholder now that the real catalog exists;
/// hard-stop, no auto-continue) still layers on top at the scripted
/// quarter break or on demand via Preview.
class LiveGameLabScreen extends StatefulWidget {
  const LiveGameLabScreen({super.key});

  @override
  State<LiveGameLabScreen> createState() => _LiveGameLabScreenState();
}

class _LiveGameLabScreenState extends State<LiveGameLabScreen> {
  var _index = -1;
  var _home = 0;
  var _away = 0;
  var _playing = false;
  var _speed = _Speed.medium;
  var _previewDark = false;
  Timer? _timer;
  final _tickerLog = <_LabBeat>[];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  _LabBeat? get _currentBeat => _index >= 0 ? _beats[_index] : null;
  int get _clockSeconds => _currentBeat?.clockSeconds ?? 600;
  String get _clockLabel {
    final seconds = _clockSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _reset() {
    setState(() {
      _index = -1;
      _home = 0;
      _away = 0;
      _tickerLog.clear();
    });
  }

  void _play() {
    if (_index >= _beats.length - 1) _reset();
    setState(() => _playing = true);
    _timer = Timer.periodic(
      Duration(milliseconds: _intervalMsFor(_speed)),
      (_) => _step(),
    );
    _step();
  }

  /// [_Speed.step]'s "Next Play" action -- advances exactly one visible
  /// beat, no timer at all. A direct GM ask (2026-08-17): "one play at a
  /// time... the user has to click to see the next play."
  void _stepOnce() {
    if (_index >= _beats.length - 1) _reset();
    _step();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  /// Whether a free throw is close/late enough to actually show --
  /// checked against the score *entering* it, before its own delta.
  /// "Under a minute, and the game is within 3 points" (2026-08-17, a
  /// direct GM ask). Every other free throw still updates the score,
  /// just silently, in the skip loop below.
  bool _isClutchFreeThrow(_LabBeat beat) =>
      beat.clockSeconds < 60 && (_home - _away).abs() <= 3;

  void _step() {
    var index = _index;
    while (true) {
      index++;
      if (index >= _beats.length) {
        _stop();
        return;
      }
      final beat = _beats[index];
      if (beat.isFreeThrow && !_isClutchFreeThrow(beat)) {
        // "Generally, I don't want to see free throws" -- apply the
        // score change and keep scanning without ever surfacing this
        // one as `current`.
        _home += beat.deltaHome;
        _away += beat.deltaAway;
        continue;
      }
      setState(() {
        _index = index;
        _home += beat.deltaHome;
        _away += beat.deltaAway;
        _tickerLog.insert(0, beat);
      });
      if (beat.isBreak) {
        _stop();
        // The lab's only scripted break is the end-of-Q1 one (deciding
        // for Q2) -- always firstHalf. A real live game would pass
        // whichever stoppage actually applies (`CoachingBreakStoppage`'s
        // own doc comment); the lab has no 2nd/3rd-quarter break
        // scripted yet to demonstrate Park the Bus's secondHalf gate.
        _openBreak(
          beat.breakLabel ?? 'COACHING BREAK',
          stoppage: CoachingBreakStoppage.firstHalf,
        );
      }
      return;
    }
  }

  Future<void> _openBreak(
    String label, {
    required CoachingBreakStoppage stoppage,
  }) async {
    // showModalBottomSheet attaches to the nearest Navigator's Overlay --
    // the app's root one, outside this screen's local Theme override --
    // so the sheet needs its own explicit Theme wrap to pick up whichever
    // brightness the Light/Dark toggle currently has selected. That
    // alone wasn't enough, though: the *sheet's own Material surface* is
    // painted by showModalBottomSheet's framework wrapper around the
    // builder's return value, outside the Theme wrap too -- fixing only
    // the inner Theme left light-background chrome around dark-themed
    // (near-invisible, light-colored) text. `backgroundColor` covers the
    // outer surface; the inner Theme covers everything drawn inside it.
    final themeData = _previewDark ? AppTheme.dark() : AppTheme.light();
    await showModalBottomSheet<CoachingOption>(
      context: context,
      backgroundColor: themeData.colorScheme.surface,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: themeData,
        child: _CoachingBreakSheet(
          label: label,
          homeAbbreviation: _homeTeam.abbreviation,
          awayAbbreviation: _awayTeam.abbreviation,
          homeScore: _home,
          awayScore: _away,
          stoppage: stoppage,
        ),
      ),
    );
    // The pick is discarded here -- this lab has no live match to resume
    // into. A real implementation would feed it into `match_engine.dart`'s
    // `homeCoachingPicker`/`awayCoachingPicker` for the resumed segment.
  }

  @override
  Widget build(BuildContext context) {
    // A local Light/Dark override (2026-08-17, a direct GM ask) -- team
    // colors that read fine in one brightness can go unreadable in the
    // other (a lime green washes out in light mode, a dark red vanishes
    // in dark mode), so the lab needs to preview both without the GM
    // leaving to flip the app's real theme in Settings. Wraps the real
    // `AppTheme`, not a generic fallback, so the preview is authentic.
    return Theme(
      data: _previewDark ? AppTheme.dark() : AppTheme.light(),
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Live Game Lab')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'A live, in-progress game -- one scripted possession '
              'sequence. Hit play, and see how a coaching break lands '
              'on top of it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Light')),
                ButtonSegment(value: true, label: Text('Dark')),
              ],
              selected: {_previewDark},
              onSelectionChanged: (selection) =>
                  setState(() => _previewDark = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ScoreBug(
                    homeScore: _home,
                    awayScore: _away,
                    clockLabel: _clockLabel,
                  ),
                  const Divider(height: AppSpacing.lg),
                  SizedBox(
                    height: 360,
                    child: _FullCourtPanel(
                      current: _currentBeat,
                      log: _tickerLog,
                      intervalMs: _intervalMsFor(_speed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Play/Next and the speed picker got their own rows (were
            // sharing one) once a 4th segment (Step) joined Slow/Med/
            // Fast -- 4 segments sharing a row with the play button
            // wrapped "Step" onto 2 letter-per-line, even after
            // shortening "Next Play" to "Next." Splitting them out gives
            // the segmented control the full row width it actually
            // needs.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _speed == _Speed.step
                    ? _stepOnce
                    : (_playing ? _stop : _play),
                icon: Icon(
                  _speed == _Speed.step
                      ? Icons.skip_next
                      : (_playing ? Icons.pause : Icons.play_arrow),
                ),
                label: Text(
                  _speed == _Speed.step
                      ? 'Next Play'
                      : (_playing ? 'Pause' : 'Play'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<_Speed>(
              segments: const [
                ButtonSegment(value: _Speed.slow, label: Text('Slow')),
                ButtonSegment(value: _Speed.medium, label: Text('Med')),
                ButtonSegment(value: _Speed.fast, label: Text('Fast')),
                ButtonSegment(value: _Speed.step, label: Text('Step')),
              ],
              selected: {_speed},
              onSelectionChanged: (selection) {
                setState(() => _speed = selection.first);
                // Step mode has no auto-timer at all -- just stop
                // whatever was running rather than restarting it.
                if (selection.first == _Speed.step) {
                  _stop();
                } else if (_playing) {
                  _stop();
                  _play();
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _openBreak(
                  'PREVIEW',
                  stoppage: CoachingBreakStoppage.firstHalf,
                ),
                child: const Text('Preview Coaching Break'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _index < 0
                  ? 'Ready -- ${_beats.length} scripted beats.'
                  : 'Beat ${_index + 1} of ${_beats.length}'
                        '${_currentBeat?.isBreak == true ? ' -- quarter break' : ''}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('What I need your read on', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const _QuestionItem(
              text:
                  'Highlight badges -- team-color background, computed '
                  'black/white text for guaranteed contrast. Toggle '
                  'Light/Dark above: does DSM green / KCY navy hold up '
                  'in both, or does the badge itself need a theme-aware '
                  'tint (not just the text)?',
            ),
            const _QuestionItem(
              text:
                  'The wood floor is dark-mode-only right now (light '
                  'mode stays plain, matching the court.svg reference) '
                  '-- want it in light mode too, or does the plain floor '
                  'read better there?',
            ),
            const _QuestionItem(
              text:
                  'Slow/Med/Fast are now 3.0s/2.0s/0.75s per beat -- '
                  'right range now, or still needs a slide?',
            ),
            const _QuestionItem(
              text:
                  'The break sheet itself -- right height/weight for a '
                  'hard stop you\'ll see 4+ times a game, every game?',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBug extends StatelessWidget {
  const _ScoreBug({
    required this.homeScore,
    required this.awayScore,
    required this.clockLabel,
  });

  final int homeScore;
  final int awayScore;
  final String clockLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w900,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _TeamDot(color: _awayColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _awayTeam.abbreviation,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _legibleTextColor(_awayColor, theme.brightness),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('$awayScore', style: scoreStyle),
            ],
          ),
        ),
        Column(
          children: [
            Text(
              'Q1',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              clockLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('$homeScore', style: scoreStyle),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _homeTeam.abbreviation,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _legibleTextColor(_homeColor, theme.brightness),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _TeamDot(color: _homeColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamDot extends StatelessWidget {
  const _TeamDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A full court (both ends), the home crest at center court, and colored
/// "action blips" instead of numbered player chips. Home always attacks
/// the right half, away always the left -- a fixed convention (real
/// teams swap ends at halftime; this doesn't model that), matching the
/// scoreboard bug's own away-left/home-right order. [_blipAlignment] is
/// the one place that convention lives.
class _FullCourtPanel extends StatelessWidget {
  const _FullCourtPanel({
    required this.current,
    required this.log,
    required this.intervalMs,
  });

  final _LabBeat? current;
  final List<_LabBeat> log;

  /// The current playback speed's per-beat interval -- ball-travel
  /// animations scale off it (capped at a sensible max) so a pass/shot
  /// always finishes comfortably within its own beat's time slot,
  /// however fast or slow that is.
  final int intervalMs;

  /// How many of the last plays a blip stays visible for before fading
  /// out completely.
  static const _blipLifetimePlays = 5;

  /// y-offset per [_LabBeat.chipIndex] (0-4), spreading blips up/down
  /// within whichever zone they land in rather than stacking on one
  /// point.
  static const _yOffsets = [-0.55, -0.22, 0.0, 0.22, 0.55];

  /// Matches the court diagram's own `AspectRatio` below -- needed here
  /// too since [_threePointBlipMagnitude]/[_freeThrowLineMagnitude]
  /// derive an Alignment fraction (relative to the panel's actual box)
  /// from `_FullCourtPainter`'s real feet-based measurements (relative
  /// to its actual pixel `Size`) -- the aspect ratio is the fixed bridge
  /// between those two coordinate spaces, since neither ever sees the
  /// other's units directly.
  static const _courtAspectRatio = 1.7;

  static Alignment _blipAlignment(_Team team, _Zone zone, int chipIndex) {
    if (zone == _Zone.centerCourt) return Alignment.center;
    final y = zone == _Zone.freeThrowLine
        ? 0.0
        : _yOffsets[chipIndex % _yOffsets.length];
    final magnitude = switch (zone) {
      _Zone.paint => 0.86,
      _Zone.midcourt => 0.5,
      _Zone.threePoint => _threePointBlipMagnitude(chipIndex),
      _Zone.freeThrowLine => _freeThrowLineMagnitude,
      _Zone.centerCourt => 0.0, // unreachable, handled above
    };
    // Home attacks the right (positive x), away attacks the left.
    final x = team == _Team.home ? magnitude : -magnitude;
    return Alignment(x, y);
  }

  /// How far a 3pt attempt's blip sits from center court, by
  /// [_LabBeat.chipIndex] -- derived from `_FullCourtPainter`'s own real
  /// measurements (not eyeballed) so it always lands just beyond the
  /// drawn arc, at every vertical chip position. A single flat magnitude
  /// couldn't do that: the arc sits noticeably closer to the basket at
  /// the top of the key (chipIndex 2, straight out from the rim) than it
  /// does out at the wings (chipIndex 0/4) -- a direct GM catch
  /// (2026-08-18): "not all of the 3 pointers are coming in from outside
  /// the 3pt arc."
  ///
  /// Math mirrors `_FullCourtPainter._drawEnd`'s own arc, just carried
  /// out symbolically in units where the court box's height is 1 (so the
  /// result is a size-independent Alignment fraction) rather than an
  /// actual pixel `Size` -- valid because [_courtAspectRatio] is fixed,
  /// so the ratio between width and height never changes at any
  /// rendered size.
  static double _threePointBlipMagnitude(int chipIndex) {
    const courtWidthFt = _FullCourtPainter._courtWidthFt;
    const radiusFt = _FullCourtPainter._threePointRadiusFt;
    const basketInsetFt = _FullCourtPainter._basketInsetFt;
    const safetyMarginAlignment = 0.04;

    final dyFt =
        _yOffsets[chipIndex % _yOffsets.length].abs() * (courtWidthFt / 2);
    final dxFt = math.sqrt(math.max(0.0, radiusFt * radiusFt - dyFt * dyFt));
    final basketX = _courtAspectRatio - basketInsetFt / courtWidthFt;
    final widthCenter = _courtAspectRatio / 2;
    final boundary =
        (basketX - dxFt / courtWidthFt - widthCenter) / widthCenter;
    return boundary - safetyMarginAlignment;
  }

  /// The free-throw line's own Alignment magnitude -- same
  /// symbolic-units derivation as [_threePointBlipMagnitude], off
  /// `_FullCourtPainter`'s lane depth (the free-throw line sits at the
  /// top of the lane, farthest from the baseline).
  static double get _freeThrowLineMagnitude {
    const courtWidthFt = _FullCourtPainter._courtWidthFt;
    const laneDepthFt = _FullCourtPainter._laneDepthFt;
    final lineX = _courtAspectRatio - laneDepthFt / courtWidthFt;
    final widthCenter = _courtAspectRatio / 2;
    return (lineX - widthCenter) / widthCenter;
  }

  /// Where a team's basket sits -- the ball-travel destination for every
  /// shot attempt, and (2026-08-18) an inbound blip's destination too,
  /// via [_opposingTeam]. Home's is near the right edge, away's near the
  /// left, matching [_blipAlignment]'s own home-right/away-left
  /// convention.
  static Alignment _basketAlignment(_Team team) =>
      Alignment(team == _Team.home ? 0.95 : -0.95, 0.0);

  /// The other team -- used to place an inbound blip at the *opposing*
  /// team's basket (`_LabBeat.isInbound`'s own doc comment explains why
  /// that's the inbounding team's own end).
  static _Team _opposingTeam(_Team team) =>
      team == _Team.home ? _Team.away : _Team.home;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final outline = isDark ? Colors.white : Colors.black;
    // A nice woody floor in both themes now -- dark walnut/pine for dark
    // mode, a very pale pine for light mode (a direct GM follow-up,
    // 2026-08-17: "maybe in light mode, the court becomes a super light
    // wood color?"). Light mode started plain (matching the court.svg
    // reference) before that ask.
    final floorColor = isDark
        ? const Color(0xFF4E3524)
        : const Color(0xFFF3E4C8);
    // Light mode's lines were the theme's default `outlineVariant` --
    // too pale against the pale-pine floor. A direct GM ask (2026-08-17):
    // "make the paint lines a bit darker. Doesn't need to be a full
    // black or anything, but a few shades darker than they are now." A
    // warm brown-grey (echoing the wood floor) rather than a cold grey.
    final lineColor = isDark
        ? const Color(0xFFE8D9C3)
        : const Color(0xFF7D6C52);
    final zoned = log
        .where((b) => b.zone != null && b.team != null)
        .take(_blipLifetimePlays)
        .toList();
    final recent = log.take(3).toList();
    final beat = current;
    // Capped so a pass/shot always finishes within its own beat's slot,
    // however fast or slow the current speed is.
    final passDuration = Duration(
      milliseconds: math.min(650, (intervalMs * 0.8).round()),
    );
    final shotDuration = Duration(
      milliseconds: math.min(1000, (intervalMs * 0.85).round()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.7,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FullCourtPainter(
                      lineColor: lineColor,
                      centerRingColor: _homeColor,
                      floorColor: floorColor,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  // 3x the original size, then trimmed back down 25%
                  // (2026-08-18, a direct GM follow-up) -- the
                  // center-court ring below was sized to frame the
                  // original 3x size, so it's left a little roomier
                  // around the emoji now rather than resized to match.
                  child: Text(_homeEmoji, style: const TextStyle(fontSize: 50)),
                ),
                for (var i = 0; i < zoned.length; i++)
                  Align(
                    alignment: zoned[i].isInbound
                        // An inbound blip sits behind the *opposing*
                        // team's basket -- see `_LabBeat.isInbound`'s own
                        // doc comment for why that's actually this
                        // team's own end.
                        ? _basketAlignment(_opposingTeam(zoned[i].team!))
                        : _blipAlignment(
                            zoned[i].team!,
                            zoned[i].zone!,
                            zoned[i].chipIndex ?? 0,
                          ),
                    child: _BlipDot(
                      key: ValueKey(zoned[i].displayText),
                      color: zoned[i].badgeTeam == _Team.home
                          ? _homeColor
                          : _awayColor,
                      outlineColor: outline,
                      opacity: (1 - i / _blipLifetimePlays).clamp(0.0, 1.0),
                      isNewest: i == 0,
                    ),
                  ),
                // A basketball animating between two points -- "an
                // animation between two points for an assist... a
                // shooting animation of the ball... toward the basket"
                // (2026-08-17, direct GM asks). Both key off the beat's
                // own displayText, so a new beat always gets a fresh
                // animation rather than resuming a stale one.
                if (beat != null &&
                    beat.isPass &&
                    beat.team != null &&
                    beat.passFromZone != null &&
                    beat.passFromChipIndex != null &&
                    beat.zone != null)
                  _BallTravelOverlay(
                    key: ValueKey('${beat.displayText}-pass'),
                    from: _blipAlignment(
                      beat.team!,
                      beat.passFromZone!,
                      beat.passFromChipIndex!,
                    ),
                    to: _blipAlignment(
                      beat.team!,
                      beat.zone!,
                      beat.chipIndex ?? 0,
                    ),
                    duration: passDuration,
                  ),
                if (beat != null &&
                    beat.isShotAttempt &&
                    beat.team != null &&
                    beat.zone != null) ...[
                  _ShotBall(
                    key: ValueKey('${beat.displayText}-shot'),
                    from: _blipAlignment(
                      beat.team!,
                      beat.zone!,
                      beat.chipIndex ?? 0,
                    ),
                    to: _basketAlignment(beat.badgeTeam),
                    travelDuration: shotDuration,
                    made: beat.shotMade == true,
                  ),
                  Align(
                    alignment: _basketAlignment(beat.badgeTeam),
                    child: _ShotResultPopup(
                      key: ValueKey('${beat.displayText}-result'),
                      pointsLabel: beat.shotMade != true
                          ? '✕'
                          : (beat.highlight == _Highlight.threePointer
                                ? '+3'
                                : '+2'),
                      // A made-shot popup is white in dark mode -- a
                      // direct GM catch (2026-08-17): "I'm looking at
                      // dark mode and they're hard to see" (team colors
                      // read dim against the dark wood floor). A miss's
                      // theme-provided error red already handles both
                      // themes fine on its own.
                      color: beat.shotMade != true
                          ? theme.colorScheme.error
                          : (isDark
                                ? Colors.white
                                : (beat.badgeTeam == _Team.home
                                      ? _homeColor
                                      : _awayColor)),
                      delay: shotDuration,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // A fixed height, not just whatever the content needs -- a
        // direct GM catch, live on-device: "the whole court seems to
        // keep resizing and moving around." The headline's actual
        // height varies a lot beat to beat (a bold badge plus up to 3
        // lines vs. a bare 1-line action), and since the court above it
        // is an Expanded inside this panel's own fixed-height box, every
        // headline-height change was stealing from (or giving back)
        // the court's share of that space, resizing the whole diagram
        // every single beat. Bumped from 92 to 116 (2026-08-18) to fit
        // a 3rd line -- longer player tags were ellipsizing at 2.
        SizedBox(height: 116, child: _PlayHeadline(beat: current)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 62,
          child: recent.isEmpty
              ? const SizedBox.shrink()
              : ListView.separated(
                  itemCount: recent.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 3),
                  itemBuilder: (context, i) {
                    final beat = recent[i];
                    final color = _legibleTextColor(
                      beat.badgeTeam == _Team.home ? _homeColor : _awayColor,
                      theme.brightness,
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            beat.displayText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A basketball animating from one court point to another over
/// [duration] -- "no arc necessary, just have it travel" (2026-08-17, a
/// direct GM ask). A plain [TweenAnimationBuilder], not a full
/// [AnimationController]: keyed per-use by the caller (see
/// [_FullCourtPanel]) so a new beat always starts a fresh tween from its
/// own `from` rather than animating from wherever a stale one left off.
class _BallTravelOverlay extends StatelessWidget {
  const _BallTravelOverlay({
    super.key,
    required this.from,
    required this.to,
    required this.duration,
  });

  final Alignment from;
  final Alignment to;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Alignment>(
      tween: AlignmentTween(begin: from, end: to),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, alignment, child) =>
          Align(alignment: alignment, child: child),
      child: const Text('🏀', style: TextStyle(fontSize: 20)),
    );
  }
}

/// A shot's ball -- travels from [from] to [to] over [travelDuration]
/// exactly like [_BallTravelOverlay], then resolves: a make disappears
/// (a quick fade in place), a miss bounces off in a random direction and
/// fades quickly. A direct GM ask (2026-08-17): "once the ball reaches
/// the basket in animation, it should disappear if it's a make, or
/// bounce in a random direction (then disappear quickly) if it's a
/// miss." Passes don't get this -- they just arrive and stay (see
/// [_BallTravelOverlay]); only a shot's ball needs a post-arrival fate.
class _ShotBall extends StatefulWidget {
  const _ShotBall({
    super.key,
    required this.from,
    required this.to,
    required this.travelDuration,
    required this.made,
  });

  final Alignment from;
  final Alignment to;
  final Duration travelDuration;
  final bool made;

  @override
  State<_ShotBall> createState() => _ShotBallState();
}

class _ShotBallState extends State<_ShotBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Alignment _bounceTarget;
  late final double _travelFraction;

  static const _makeFadeMs = 200;
  static const _missBounceMs = 450;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final radius = 0.10 + random.nextDouble() * 0.08;
    _bounceTarget = Alignment(
      (widget.to.x + math.cos(angle) * radius).clamp(-1.0, 1.0),
      (widget.to.y + math.sin(angle) * radius).clamp(-1.0, 1.0),
    );
    final postMs = widget.made ? _makeFadeMs : _missBounceMs;
    final totalMs = widget.travelDuration.inMilliseconds + postMs;
    _travelFraction = widget.travelDuration.inMilliseconds / totalMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        if (t <= _travelFraction) {
          final localT = _travelFraction == 0 ? 1.0 : t / _travelFraction;
          final alignment = Alignment.lerp(
            widget.from,
            widget.to,
            Curves.easeInOut.transform(localT),
          )!;
          return Align(alignment: alignment, child: child);
        }
        final postT = ((t - _travelFraction) / (1 - _travelFraction)).clamp(
          0.0,
          1.0,
        );
        final alignment = widget.made
            ? widget.to
            : Alignment.lerp(
                widget.to,
                _bounceTarget,
                Curves.easeOut.transform(postT),
              )!;
        return Align(
          alignment: alignment,
          child: Opacity(opacity: 1 - postT, child: child),
        );
      },
      child: const Text('🏀', style: TextStyle(fontSize: 20)),
    );
  }
}

/// The made/miss result at the basket -- a brief flash-in then a
/// float-up-and-fade, timed to appear once the ball's travel animation
/// actually arrives (2026-08-17, a direct GM ask): "when it hits the
/// basket, it pops up 2pts, 3pts, or a red X for a miss... if the text
/// could float up and fade away I'd love that." [delay] is the shot's
/// own travel duration -- the popup stays invisible until
/// then, so it never appears to precede the ball's arrival.
class _ShotResultPopup extends StatefulWidget {
  const _ShotResultPopup({
    super.key,
    required this.pointsLabel,
    required this.color,
    required this.delay,
  });

  final String pointsLabel;
  final Color color;
  final Duration delay;

  @override
  State<_ShotResultPopup> createState() => _ShotResultPopupState();
}

class _ShotResultPopupState extends State<_ShotResultPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // A quick flash in (first 15% of the animation), then float up
        // while fading out over the rest.
        final opacity = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -24 * t),
            child: Transform.scale(
              scale: t < 0.15 ? 0.7 + (0.3 * t / 0.15) : 1.0,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        widget.pointsLabel,
        style: TextStyle(
          color: widget.color,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
    );
  }
}

/// The current play's headline -- a colored keyword badge above the
/// "#N Name (POS TEAM) action" line for a notable play
/// ([_LabBeat.highlight] != none), a plain (deliberately not bold --
/// "Bold is reserved for steals and buckets, and blocks," 2026-08-17)
/// "TEAM Pass" label for an assist's pass half, or just the plain line
/// otherwise.
class _PlayHeadline extends StatelessWidget {
  const _PlayHeadline({required this.beat});

  final _LabBeat? beat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = beat;
    if (current == null) {
      return Text(
        'Tap Play to start the possession chain.',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      );
    }
    final label = current.highlight.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          _HighlightBadge(team: current.badgeTeam, label: label),
          const SizedBox(height: 4),
        ] else if (current.isPass) ...[
          Text(
            '${current.badgeTeam == _Team.home ? _homeTeam.abbreviation : _awayTeam.abbreviation} '
            'Pass',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _legibleTextColor(
                current.badgeTeam == _Team.home ? _homeColor : _awayColor,
                theme.brightness,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          current.displayText,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          // 2 -> 3 (2026-08-18, a direct GM catch): longer player tags
          // ("#N Name (POS TEAM)") plus a full-sentence phrase were
          // ellipsizing at 2 lines. See the SizedBox above for the
          // matching fixed-height bump.
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A bold colored keyword tag ("DSM 3PTS", "KCY STEAL") -- team color as
/// the *background*, with the text color computed from that
/// background's luminance rather than ever using the team color as text
/// directly. That's the actual fix for the GM's own concern (2026-08-17):
/// "some team colors won't be readable, depending on dark mode vs light
/// mode... a lime green isn't readable [on white], a dark red won't be
/// readable [on black]" -- as long as the badge itself provides the
/// contrast, the team color underneath doesn't matter.
class _HighlightBadge extends StatelessWidget {
  const _HighlightBadge({required this.team, required this.label});

  final _Team team;
  final String label;

  @override
  Widget build(BuildContext context) {
    final background = team == _Team.home ? _homeColor : _awayColor;
    final foreground = background.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;
    final abbreviation = team == _Team.home
        ? _homeTeam.abbreviation
        : _awayTeam.abbreviation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$abbreviation $label',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A single action blip -- flashes (a quick double-pulse scale) the
/// instant it's newest, then just tracks [opacity] as the parent ages
/// it out over the next few plays. Keyed per-beat by the caller (see
/// [_FullCourtPanel]) so a brand-new beat gets a brand-new [State] (and
/// therefore a fresh flash), while an aging blip keeps the same [State]
/// and just smoothly dims via [AnimatedOpacity].
class _BlipDot extends StatefulWidget {
  const _BlipDot({
    super.key,
    required this.color,
    required this.outlineColor,
    required this.opacity,
    required this.isNewest,
  });

  final Color color;
  final Color outlineColor;
  final double opacity;
  final bool isNewest;

  @override
  State<_BlipDot> createState() => _BlipDotState();
}

class _BlipDotState extends State<_BlipDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _flashController;
  Animation<double>? _flashScale;

  @override
  void initState() {
    super.initState();
    if (!widget.isNewest) return;
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _flashScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.6, end: 1.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _flashController!, curve: Curves.easeInOut),
        );
    _flashController!.forward();
  }

  @override
  void dispose() {
    _flashController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedOpacity(
      opacity: widget.opacity,
      duration: const Duration(milliseconds: 400),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          border: Border.all(color: widget.outlineColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
    final flashScale = _flashScale;
    if (flashScale == null) return dot;
    return AnimatedBuilder(
      animation: flashScale,
      builder: (context, child) =>
          Transform.scale(scale: flashScale.value, child: child),
      child: dot,
    );
  }
}

/// Modeled on a real court-diagram reference the GM supplied (2026-08-17,
/// `court.svg`) -- lane, free-throw circle, 3pt line, backboard/rim at
/// each end, center circle -- deliberately less detailed than that
/// reference (no dashed free-throw-circle half, no lane hash marks).
/// Sharp corners, not rounded, to match the reference's clean
/// architectural-line-drawing look.
class _FullCourtPainter extends CustomPainter {
  _FullCourtPainter({
    required this.lineColor,
    required this.centerRingColor,
    this.floorColor,
  });

  final Color lineColor;
  final Color centerRingColor;

  /// A wood-toned floor fill, dark-mode only -- `null` in light mode
  /// keeps the plain floor from the court.svg reference.
  final Color? floorColor;

  /// Real NBA court measurements, in feet -- every shape below is scaled
  /// off these via [_drawEnd]'s `px` helper rather than eyeballed
  /// fractions, so the lane, free-throw circle, and 3pt line all land in
  /// true proportion to each other and to the court (2026-08-17, a
  /// direct GM ask: "more realistic to the size/shape of the court").
  /// [courtWidthFt] is the calibration basis (mapped to [Size.height],
  /// the landscape court's constrained dimension) -- the real 94ft
  /// length doesn't need to fit exactly since this widget isn't drawn at
  /// the real 94:50 aspect ratio; the leftover width just reads as extra
  /// mid-court floor space, which a real court has anyway.
  static const _courtWidthFt = 50.0;
  static const _laneDepthFt = 19.0;
  static const _laneWidthFt = 16.0;
  static const _threePointRadiusFt = 23.75;

  /// How far the 3pt line's straight corner section sits in from the
  /// sideline -- real courts don't run the arc all the way to the
  /// baseline; it flattens into a short straight line at each corner
  /// first.
  static const _threePointCornerInsetFt = 3.0;
  static const _basketInsetFt = 5.25;
  static const _backboardInsetFt = 4.0;

  /// Draws one end's lane, free-throw circle, 3pt line, and
  /// backboard/rim. [onRight] mirrors every measurement horizontally --
  /// the geometry is otherwise identical for both ends.
  void _drawEnd(
    Canvas canvas,
    Size size,
    Paint linePaint, {
    required bool onRight,
  }) {
    final feetPerPixel = size.height / _courtWidthFt;
    double px(double feet) => feet * feetPerPixel;

    final baselineX = onRight ? size.width - 4 : 4.0;
    final laneWidth = px(_laneDepthFt);
    final laneHeight = px(_laneWidthFt);
    final laneRect = onRight
        ? Rect.fromLTWH(
            size.width - 4 - laneWidth,
            (size.height - laneHeight) / 2,
            laneWidth,
            laneHeight,
          )
        : Rect.fromLTWH(
            4,
            (size.height - laneHeight) / 2,
            laneWidth,
            laneHeight,
          );
    canvas.drawRect(laneRect, linePaint);

    final ftCircleCenter = Offset(
      onRight ? laneRect.left : laneRect.right,
      size.height / 2,
    );
    canvas.drawCircle(ftCircleCenter, laneHeight / 2, linePaint);

    // The 3pt line: a straight section at each corner (inset from the
    // sideline, running in from the baseline), then an arc connecting
    // them, bowing away from the basket toward mid-court. Solving for
    // where the arc meets the straight lines: dy is fixed by the corner
    // inset, dx (and so the arc's angular span) falls out of the
    // 3pt radius via Pythagoras.
    final basketX = onRight
        ? size.width - 4 - px(_basketInsetFt)
        : 4 + px(_basketInsetFt);
    final threePointRadius = px(_threePointRadiusFt);
    final dy = size.height / 2 - px(_threePointCornerInsetFt);
    final dx = math.sqrt(threePointRadius * threePointRadius - dy * dy);
    final cornerY1 = size.height / 2 - dy;
    final cornerY2 = size.height / 2 + dy;
    final transitionX = onRight ? basketX - dx : basketX + dx;

    canvas.drawLine(
      Offset(baselineX, cornerY1),
      Offset(transitionX, cornerY1),
      linePaint,
    );
    canvas.drawLine(
      Offset(baselineX, cornerY2),
      Offset(transitionX, cornerY2),
      linePaint,
    );
    final halfSpan = math.asin(dy / threePointRadius);
    final startAngle = onRight ? math.pi - halfSpan : -halfSpan;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(basketX, size.height / 2),
        radius: threePointRadius,
      ),
      startAngle,
      2 * halfSpan,
      false,
      linePaint,
    );

    // A short backboard tick plus a small rim, tucked just inside the
    // baseline -- a light nod to the reference's backboard/rim glyph
    // without the restricted-area arc that came with it.
    final backboardX = onRight
        ? size.width - 4 - px(_backboardInsetFt)
        : 4 + px(_backboardInsetFt);
    canvas.drawLine(
      Offset(backboardX, size.height / 2 - px(3)),
      Offset(backboardX, size.height / 2 + px(3)),
      linePaint,
    );
    final rimX = onRight ? backboardX - px(0.75) : backboardX + px(0.75);
    canvas.drawCircle(Offset(rimX, size.height / 2), px(0.75), linePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final courtRect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final floor = floorColor;
    if (floor != null) {
      canvas.drawRect(courtRect, Paint()..color = floor);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(courtRect, linePaint);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(center.dx, 4),
      Offset(center.dx, size.height - 4),
      linePaint,
    );

    _drawEnd(canvas, size, linePaint, onRight: true);
    _drawEnd(canvas, size, linePaint, onRight: false);

    // A center-court "floor decal" -- a faint team-color tinted disc,
    // doing double duty as the reference's plain half-court circle.
    // Sized to comfortably frame the 3x-larger center emoji (see
    // _FullCourtPanel) rather than the emoji overflowing it. The ring
    // itself is drawn in the *court's own line color*, not the team
    // color -- a direct GM catch in dark mode (2026-08-17): "I can't see
    // the center circle... it's black, and it should probably match the
    // rest of the paint." The team-color ring read fine in light mode
    // but nearly vanished against the dark wood floor.
    final decalRadius = size.height * 0.24;
    canvas.drawCircle(
      center,
      decalRadius,
      Paint()..color = centerRingColor.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      center,
      decalRadius,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _FullCourtPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.centerRingColor != centerRingColor ||
      oldDelegate.floorColor != floorColor;
}

/// The coaching-break sheet -- the real, locked [CoachingOption] catalog
/// (2026-08-17, `0B_Planned.md`'s quarter-break bullet), a real 3-option
/// draw via [offerCoachingOptions] rather than a hand-picked list, and a
/// hard stop (`isDismissible: false`, `enableDrag: false`) so it always
/// waits for an explicit "Resume Game" tap. Replaces the earlier
/// DefensiveTactic-re-pick placeholder that stood in for this before the
/// catalog existed.
class _CoachingBreakSheet extends StatefulWidget {
  const _CoachingBreakSheet({
    required this.label,
    required this.homeAbbreviation,
    required this.awayAbbreviation,
    required this.homeScore,
    required this.awayScore,
    required this.stoppage,
  });

  final String label;
  final String homeAbbreviation;
  final String awayAbbreviation;
  final int homeScore;
  final int awayScore;
  final CoachingBreakStoppage stoppage;

  @override
  State<_CoachingBreakSheet> createState() => _CoachingBreakSheetState();
}

class _CoachingBreakSheetState extends State<_CoachingBreakSheet> {
  late final List<CoachingOption> _offered = offerCoachingOptions(
    math.Random(),
    stoppage: widget.stoppage,
    // The lab doesn't track real recent-scoring history the way a live
    // game would -- Stop the Bleeding's trigger (`0B_Planned.md`'s
    // quarter-break bullet) is exercised directly in
    // `coaching_option_test.dart` instead of here.
    opponentUnansweredRun: 0,
  );
  CoachingOption? _picked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.homeAbbreviation} ${widget.homeScore} - '
              '${widget.awayScore} ${widget.awayAbbreviation}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Coaching Adjustment', style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              "A nudge for the team, not a full gameplan change -- one "
              "quarter's worth (or the final ~2 minutes, at a late-game "
              'break).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final option in _offered) ...[
              if (option != _offered.first)
                const SizedBox(height: AppSpacing.xs),
              _LabCoachingOption(
                option: option,
                isSelected: option == _picked,
                onTap: () => setState(() => _picked = option),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_picked),
              child: Text(
                _picked == null ? 'Resume Game (no pick)' : 'Resume Game',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabCoachingOption extends StatelessWidget {
  const _LabCoachingOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final CoachingOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.shorthand,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionItem extends StatelessWidget {
  const _QuestionItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
