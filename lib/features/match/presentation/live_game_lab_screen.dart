import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/onboarding/quick_start_teams.dart';
import '../../league/domain/team.dart';
import '../../matchup/domain/coaching_option.dart';
import '../../matchup/domain/defensive_tactic.dart';
import '../../player/domain/player.dart';
import '../../roster/generation/ai_roster_generator.dart';
import '../../season/application/franchise_rosters.dart';
import '../../season/domain/game_result.dart';
import '../../season/domain/scheduled_game.dart';
import '../../season/generation/season_advancer.dart';
import '../../season/presentation/game_result_screen.dart';
import '../domain/match_result.dart';
import '../engine/match_engine.dart';
import '../engine/substitution_policy.dart';
import 'live_beat_translator.dart';

/// Which team (if any) a beat belongs to -- aliases the real, public
/// [LiveTeam] (2026-08-18, `TODO.md` item 8's live-game architecture
/// stage 4 -- this screen went from a hand-scripted demo to driving a
/// real [simulateMatchLive] game). Kept as a private alias rather than a
/// mass rename so every widget below built and verified against the old
/// name (`_FullCourtPanel`'s geometry fixes, the blip/animation code)
/// keeps compiling unchanged.
typedef _Team = LiveTeam;

/// Aliases the real, public [LiveZone] -- see [_Team]'s own doc comment.
typedef _Zone = LiveZone;

/// Aliases the real, public [LiveHighlight] -- see [_Team]'s own doc
/// comment. [LiveHighlightLabel]'s `.label` getter (imported from
/// `live_beat_translator.dart`) covers the same `.label` access this
/// file's widgets already use; no local extension needed anymore.
typedef _Highlight = LiveHighlight;

/// Aliases the real, public [LiveBeat] -- see [_Team]'s own doc comment.
/// Built by [LiveBeatTranslator] from a real [simulateMatchLive] game now,
/// not a hand-authored script.
typedef _LabBeat = LiveBeat;

/// Playback speed for the beat sequence -- a `SegmentedButton` picker
/// (2026-08-17, a direct GM ask), same pattern the Settings theme picker
/// already uses. Intervals slid slower on a same-session follow-up ask
/// ("let's slide those speed a little") -- the first pass
/// (1.8s/1.1s/0.55s) read as too fast to actually read a play. [step]
/// added on a later follow-up ask ("one play at a time... the user has
/// to click to see the next play") -- no auto-timer at all in that mode,
/// see [_LiveGameLabScreenState._stepOnce]. Governs how fast the screen
/// *displays* beats a real game already computed instantly -- nothing
/// about the simulation itself is gated on this.
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

/// Started life as a dev-only lab (reachable from Settings -- "a direct GM
/// ask, 2026-08-17, following the stamina/fatigue system landing": "I want
/// to see it in the app," not a design mockup elsewhere) for the live-game
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
///
/// Now does double duty (2026-08-18, `TODO.md` item 8's live-game
/// architecture stage 5 -- "yep, in-place replacement plz" was the GM's
/// own call at stage 4 for folding the real engine into this same screen
/// rather than building a parallel one; stage 5 continues that same
/// in-place approach rather than forking a second screen file). [franchise]
/// and [game] both `null` (the default) keeps every bit of the original
/// dev-lab behavior: 2 self-generated AI rosters wearing the Quick Start
/// Dragons/Aviators identity, the Light/Dark preview toggle, and the
/// "Preview Coaching Break"/GM-questions dev chrome. Given both, this
/// drives the GM's own real scheduled game instead -- real bench-ordered
/// rosters, real coach bonuses, the real picked [DefensiveTactic], no dev
/// chrome, auto-starting immediately rather than waiting for a first Play
/// tap (the GM already tapped Play Game to get here) -- and reports the
/// finished [MatchResult] to [onGameComplete] instead of just sitting on
/// the final score forever.
class LiveGameLabScreen extends ConsumerStatefulWidget {
  const LiveGameLabScreen({
    super.key,
    this.franchise,
    this.game,
    this.ownDefenseTactic,
  }) : assert(
         (franchise == null) == (game == null),
         'franchise and game must both be given (real game) or both left '
         'null (dev-lab demo)',
       );

  final Franchise? franchise;
  final ScheduledGame? game;
  final DefensiveTactic? ownDefenseTactic;

  /// Whether this screen is driving the GM's own real game rather than the
  /// dev-lab demo -- every other real-vs-demo branch below keys off this
  /// rather than re-checking [franchise]/[game] separately.
  bool get isReal => franchise != null;

  @override
  ConsumerState<LiveGameLabScreen> createState() => _LiveGameLabScreenState();
}

class _LiveGameLabScreenState extends ConsumerState<LiveGameLabScreen> {
  var _home = 0;
  var _away = 0;
  var _playing = false;
  var _speed = _Speed.medium;
  var _previewDark = false;
  var _gameStarted = false;
  var _gameOver = false;
  var _beatsShown = 0;
  _LabBeat? _currentBeat;
  final _tickerLog = <_LabBeat>[];

  /// A fresh 12-player roster per side, generated the same way any
  /// AI-vs-AI league game gets one when [LiveGameLabScreen.isReal] is
  /// false (2026-08-18, `TODO.md` item 8's live-game architecture stage 4)
  /// -- real names/positions/jersey numbers, not the earlier hand-invented
  /// mini-roster a hand-scripted demo needed. Generated once per screen
  /// visit, in [initState]; replaying via [_startGame] reuses the same two
  /// rosters so a GM can actually get to know these players across a few
  /// replays, while the game itself is a fresh simulation every time. When
  /// [LiveGameLabScreen.isReal] is true, these are the GM's own real
  /// scheduled game's 2 real rosters instead (still set once, in
  /// [initState]).
  late final List<Player> _homeRoster;
  late final List<Player> _awayRoster;
  late LiveBeatTranslator _translator;

  /// The 5 pieces of team identity every rendering widget below needs --
  /// the Quick Start Dragons/Aviators' hardcoded look in the dev lab, or
  /// the GM's own real opponent's real [Team] data for a real game. Used
  /// to be 5 separate module-level constants (fine when this screen only
  /// ever showed the same 2 demo teams); now instance fields set once in
  /// [initState], since a real game's identity isn't known until then.
  late final String _homeAbbreviation;
  late final String _awayAbbreviation;
  late final Color _homeColor;
  late final Color _awayColor;
  late final String _homeEmoji;

  /// Resolved by whatever advances the currently-displayed beat -- a
  /// speed-driven [Timer] in auto-play, or a "Next Play" tap in
  /// [_Speed.step]. [_onSegmentComplete] awaits this between every beat
  /// it shows, which is also what lets `simulateMatchLive`'s own
  /// computation stay paced to the GM's chosen speed even though the
  /// engine itself finishes a whole segment instantly.
  Completer<void>? _advanceCompleter;

  /// The pending timer behind [_advanceCompleter], if any -- cancelled in
  /// [dispose] so backing out mid-game (a real live game, unlike the dev
  /// lab, is reachable from a normal Navigator push a GM can back out of)
  /// doesn't leak a live `Timer` that outlives this State. A real bug this
  /// screen actually had until a widget test caught it: nothing here used
  /// to store or cancel this at all.
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final franchise = widget.franchise;
    final game = widget.game;
    if (franchise != null && game != null) {
      final rosters = rostersByAbbreviation(franchise);
      _homeRoster = rosters[game.homeTeamAbbreviation]!;
      _awayRoster = rosters[game.awayTeamAbbreviation]!;
      _homeAbbreviation = game.homeTeamAbbreviation;
      _awayAbbreviation = game.awayTeamAbbreviation;
      _homeColor = teamByAbbreviation(
        franchise,
        game.homeTeamAbbreviation,
      ).colors.primary;
      _awayColor = teamByAbbreviation(
        franchise,
        game.awayTeamAbbreviation,
      ).colors.primary;
      _homeEmoji = teamByAbbreviation(
        franchise,
        game.homeTeamAbbreviation,
      ).emoji;
      // The GM already tapped Play Game on the Matchup Preview screen to
      // get here -- a real game auto-starts rather than making them tap
      // Play a 2nd, redundant time. Deferred a frame (rather than called
      // directly here) since `_startGame` calls `setState`, which isn't
      // safe before this widget's first build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startGame());
    } else {
      final random = math.Random();
      _homeRoster = generateAiRoster(random).map((m) => m.player).toList();
      _awayRoster = generateAiRoster(random).map((m) => m.player).toList();
      _homeAbbreviation = kQuickStartDesMoinesDragons.abbreviation;
      _awayAbbreviation = kQuickStartKansasCityAviators.abbreviation;
      _homeColor = _colorFromHex(kQuickStartDesMoinesDragons.colors.primaryHex);
      _awayColor = _colorFromHex(
        kQuickStartKansasCityAviators.colors.primaryHex,
      );
      _homeEmoji = kQuickStartDesMoinesDragons.emoji;
    }
  }

  String get _quarterLabel {
    final quarter = _currentBeat?.quarter ?? 1;
    if (quarter <= 4) return 'Q$quarter';
    final overtimeNumber = quarter - 4;
    return overtimeNumber == 1 ? 'OT' : '${overtimeNumber}OT';
  }

  String get _clockLabel {
    final seconds = (_currentBeat?.clockSeconds ?? 600).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  /// Whether a free throw is close/late enough to actually show --
  /// checked against the score *entering* it, before its own delta.
  /// "Under a minute, and the game is within 3 points" (2026-08-17, a
  /// direct GM ask). Every other free throw still updates the score,
  /// just silently, without ever becoming [_currentBeat].
  bool _isClutchFreeThrow(_LabBeat beat) =>
      beat.clockSeconds < 60 && (_home - _away).abs() <= 3;

  /// Kicks off a real [simulateMatchLive] game -- called the first time
  /// Play/Next is tapped in the dev lab (and again any time either is
  /// tapped after the previous demo game finished), or automatically via
  /// [initState]'s post-frame callback for a real game. [_onSegmentComplete]
  /// and [_liveCoachingPicker] below are where the actual watching
  /// experience and the real coaching-break sheet live; this just starts
  /// the engine and resets the on-screen state to match a fresh game.
  void _startGame() {
    setState(() {
      _home = 0;
      _away = 0;
      _currentBeat = null;
      _tickerLog.clear();
      _beatsShown = 0;
      _gameStarted = true;
      _gameOver = false;
      _playing = true;
    });
    _translator = LiveBeatTranslator(
      homeRoster: _homeRoster,
      awayRoster: _awayRoster,
      homeAbbreviation: _homeAbbreviation,
      awayAbbreviation: _awayAbbreviation,
    );

    final franchise = widget.franchise;
    final game = widget.game;
    final isReal = franchise != null && game != null;
    // The GM's own team only (`TODO.md` item 8's "GM's own scheduled game
    // only" scope) -- their side gets the real interactive picker; the AI
    // opponent gets none, same "no picker, no offer" posture `simulateMatch`
    // itself already established. In the dev lab, home (DSM) always stands
    // in for "the GM's side."
    final ownAbbreviation = isReal ? franchise.team.abbreviation : null;
    final homeIsOwn = !isReal || _homeAbbreviation == ownAbbreviation;
    final awayIsOwn = isReal && _awayAbbreviation == ownAbbreviation;
    final coaches = isReal ? coachesByAbbreviation(franchise) : null;

    simulateMatchLive(
      isReal
          ? math.Random(
              franchise.seasonSeed +
                  kSeasonAdvanceSeedOffset +
                  franchise.seasonProgress.nextGameDayIndex,
            )
          : math.Random(),
      homeRoster: _homeRoster,
      awayRoster: _awayRoster,
      // Only the GM's own real side reads its real bench order --
      // `_simulateOneGame`'s exact convention, mirrored here so a live
      // game plays under the same rules an instant-sim of it would have.
      homeTargetMinutes: homeIsOwn && isReal
          ? targetMinutesForOrderedRoster(_homeRoster)
          : null,
      awayTargetMinutes: awayIsOwn
          ? targetMinutesForOrderedRoster(_awayRoster)
          : null,
      homeCoach: coaches?[_homeAbbreviation],
      awayCoach: coaches?[_awayAbbreviation],
      homeDefenseTactic: homeIsOwn && isReal
          ? (widget.ownDefenseTactic ?? DefensiveTactic.balanced)
          : DefensiveTactic.balanced,
      awayDefenseTactic: awayIsOwn
          ? (widget.ownDefenseTactic ?? DefensiveTactic.balanced)
          : DefensiveTactic.balanced,
      homeLiveCoachingPicker: homeIsOwn ? _liveCoachingPicker : null,
      awayLiveCoachingPicker: awayIsOwn ? _liveCoachingPicker : null,
      onSegmentComplete: _onSegmentComplete,
    ).then((MatchResult result) async {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _gameOver = true;
      });
      if (isReal) await _finishDayAndShowResult(franchise, result);
    });
  }

  /// Once the GM's own live game is fully resolved, folds it into the rest
  /// of today's schedule -- every other game the GM didn't watch still
  /// gets bulk-simulated the normal instant way here
  /// (`advanceGameDayWithOwnResult`) -- then hands off to the same
  /// [GameResultScreen] the Sim Instantly path already uses, so the two
  /// paths converge on one identical post-game experience.
  Future<void> _finishDayAndShowResult(
    Franchise franchise,
    MatchResult ownMatch,
  ) async {
    final results = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceGameDayWithOwnResult(
          ownMatch,
          ownDefenseTactic: widget.ownDefenseTactic,
        );
    if (!mounted) return;

    final ownGame = ownGameResultFrom(results, franchise.team.abbreviation);
    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (!mounted) return;

    if (updatedFranchise == null || ownGame == null) {
      // Shouldn't normally happen -- this screen only ever gets pushed for
      // a day the GM's own team was actually scheduled -- but fail safely
      // back rather than leaving the final score frozen on screen forever.
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            GameResultScreen(franchise: updatedFranchise, result: ownGame),
      ),
    );
  }

  /// `simulateMatchLive`'s per-segment handoff -- translates this
  /// segment's real events into beats and shows them one at a time,
  /// awaiting [_waitForAdvance] between each so the engine (which
  /// computed all of this instantly) only moves on to the next segment
  /// once the GM has actually seen this one at their chosen pace.
  Future<void> _onSegmentComplete(LiveGameSegment segment) async {
    for (final beat in _translator.translateSegment(segment)) {
      if (!mounted) return;
      if (beat.isFreeThrow && !_isClutchFreeThrow(beat)) {
        setState(() {
          _home += beat.deltaHome;
          _away += beat.deltaAway;
        });
        continue;
      }
      // Fast speed additionally skips every non-shot beat entirely --
      // still applied (the score, if any) and still fed through the real
      // engine/translator exactly the same either way, just never
      // rendered or waited on. A direct GM ask (2026-08-18): with the
      // real engine's genuine amount of ball movement now visible (far
      // more passing than the Lab's old hand-scripted demo ever showed),
      // Fast needs to blow through everything that isn't a shot attempt
      // to actually feel fast -- "eliminate all plays that aren't shots
      // ... just show shot attempts (misses and makes)." Free throws
      // aren't touched by this check -- the clutch gate above already
      // decides whether *any* speed shows a given one.
      if (_speed == _Speed.fast && !beat.isShotAttempt && !beat.isFreeThrow) {
        setState(() {
          _home += beat.deltaHome;
          _away += beat.deltaAway;
        });
        continue;
      }
      setState(() {
        _currentBeat = beat;
        _home += beat.deltaHome;
        _away += beat.deltaAway;
        _tickerLog.insert(0, beat);
        _beatsShown++;
      });
      await _waitForAdvance();
      if (!mounted) return;
    }
  }

  Future<void> _waitForAdvance() {
    final completer = Completer<void>();
    _advanceCompleter = completer;
    if (_speed != _Speed.step) {
      // A shot attempt's own +2/+3/miss-X result needs real time on
      // screen to actually be readable -- a direct GM catch (2026-08-18):
      // "it's up there for a split second, can't read it" at Fast's own
      // 750ms base pace (barely longer than the ball's own travel
      // animation). Quadrupled for exactly this one beat type, at Fast
      // speed only -- every non-shot beat Fast still shows (assists,
      // blocks, steals) keeps the normal brisk pace; only the shot result
      // itself needs the extra room to breathe.
      final baseMs = _intervalMsFor(_speed);
      final beat = _currentBeat;
      final ms = (_speed == _Speed.fast && beat != null && beat.isShotAttempt)
          ? baseMs * 4
          : baseMs;
      _advanceTimer = Timer(Duration(milliseconds: ms), () {
        if (_playing && !completer.isCompleted) completer.complete();
      });
    }
    return completer.future;
  }

  void _completePendingAdvance() {
    _advanceTimer?.cancel();
    final completer = _advanceCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _onPlayPressed() {
    if (!_gameStarted || _gameOver) {
      _startGame();
      return;
    }
    setState(() => _playing = true);
    // Resuming from pause advances right away rather than waiting out
    // whatever was left of the paused beat's interval -- simple, and
    // "Play" reads as "go" either way.
    _completePendingAdvance();
  }

  void _onPausePressed() => setState(() => _playing = false);

  /// [_Speed.step]'s "Next Play" action -- a direct GM ask (2026-08-17):
  /// "one play at a time... the user has to click to see the next play."
  void _stepOnce() {
    if (!_gameStarted || _gameOver) {
      _startGame();
      return;
    }
    _completePendingAdvance();
  }

  /// The real coaching-break sheet -- awaited by `simulateMatchLive`
  /// itself (via [_startGame]'s `homeLiveCoachingPicker`), so this is
  /// called automatically at every real break, right after this
  /// segment's beats have finished playing. [CoachingBreakContext.offered]
  /// is the engine's own already-drawn 3-option menu
  /// (`offerCoachingOptions`) -- this doesn't re-roll anything, just
  /// shows it and returns whatever the GM picks.
  Future<CoachingOption?> _liveCoachingPicker(
    CoachingBreakContext context,
  ) async {
    if (!mounted) return null;
    return _openBreak('Q${context.quarter} BREAK', offered: context.offered);
  }

  Future<CoachingOption?> _openBreak(
    String label, {
    required List<CoachingOption> offered,
  }) {
    // showModalBottomSheet attaches to the nearest Navigator's Overlay --
    // the app's root one, outside this screen's local Theme override --
    // so the sheet needs its own explicit Theme wrap to pick up whichever
    // brightness is actually in effect. That alone wasn't enough, though:
    // the *sheet's own Material surface* is painted by
    // showModalBottomSheet's framework wrapper around the builder's return
    // value, outside the Theme wrap too -- fixing only the inner Theme left
    // light-background chrome around dark-themed (near-invisible,
    // light-colored) text. `backgroundColor` covers the outer surface; the
    // inner Theme covers everything drawn inside it. A real game has no
    // Light/Dark preview toggle of its own (see [build]) -- it just carries
    // the ambient app theme through, same as every other real screen.
    final themeData = widget.isReal
        ? Theme.of(context)
        : (_previewDark ? AppTheme.dark() : AppTheme.light());
    return showModalBottomSheet<CoachingOption>(
      context: context,
      backgroundColor: themeData.colorScheme.surface,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: themeData,
        child: _CoachingBreakSheet(
          label: label,
          homeAbbreviation: _homeAbbreviation,
          awayAbbreviation: _awayAbbreviation,
          homeScore: _home,
          awayScore: _away,
          offered: offered,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A local Light/Dark override, dev-lab only (2026-08-17, a direct GM
    // ask) -- team colors that read fine in one brightness can go
    // unreadable in the other (a lime green washes out in light mode, a
    // dark red vanishes in dark mode), so the lab needs to preview both
    // without the GM leaving to flip the app's real theme in Settings.
    // Wraps the real `AppTheme`, not a generic fallback, so the preview is
    // authentic. A real game has no such toggle -- it just renders under
    // whatever theme the rest of the app is already in, like every other
    // real screen (`_openBreak`'s own doc comment covers the sheet's own
    // matching choice).
    if (!widget.isReal) {
      return Theme(
        data: _previewDark ? AppTheme.dark() : AppTheme.light(),
        child: Builder(builder: _buildScaffold),
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isReal
              ? '$_awayAbbreviation @ $_homeAbbreviation'
              : 'Live Game Lab',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'A real, simulated game -- the same engine every AI-vs-AI '
              'league game runs through, just watched live.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!widget.isReal) ...[
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
            ],
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
                    quarterLabel: _quarterLabel,
                    homeAbbreviation: _homeAbbreviation,
                    awayAbbreviation: _awayAbbreviation,
                    homeColor: _homeColor,
                    awayColor: _awayColor,
                  ),
                  const Divider(height: AppSpacing.lg),
                  SizedBox(
                    height: 360,
                    child: _FullCourtPanel(
                      current: _currentBeat,
                      log: _tickerLog,
                      intervalMs: _intervalMsFor(_speed),
                      homeAbbreviation: _homeAbbreviation,
                      awayAbbreviation: _awayAbbreviation,
                      homeColor: _homeColor,
                      awayColor: _awayColor,
                      homeEmoji: _homeEmoji,
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
                    : (_playing ? _onPausePressed : _onPlayPressed),
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
                final wasStep = _speed == _Speed.step;
                setState(() => _speed = selection.first);
                // A pending wait created under Step mode has no timer at
                // all -- switching to an auto speed while playing would
                // otherwise strand it forever, so kick it forward right
                // away instead of waiting for a tap that's no longer
                // coming.
                if (wasStep && selection.first != _Speed.step && _playing) {
                  _completePendingAdvance();
                }
              },
            ),
            if (!widget.isReal) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _openBreak(
                    'PREVIEW',
                    offered: offerCoachingOptions(
                      math.Random(),
                      stoppage: CoachingBreakStoppage.firstHalf,
                      opponentUnansweredRun: 0,
                    ),
                  ),
                  child: const Text('Preview Coaching Break'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              !_gameStarted
                  ? 'Ready -- tap Play to start a real simulated game.'
                  : (_gameOver
                        ? 'Final -- $_beatsShown beats shown.'
                        : 'Beat $_beatsShown so far...'),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!widget.isReal) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'What I need your read on',
                style: theme.textTheme.titleLarge,
              ),
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
    required this.quarterLabel,
    required this.homeAbbreviation,
    required this.awayAbbreviation,
    required this.homeColor,
    required this.awayColor,
  });

  final int homeScore;
  final int awayScore;
  final String clockLabel;

  /// "Q1"/"Q4"/"OT"/"2OT" -- a real game can run past regulation
  /// (`simulateMatchLive`'s own overtime handling), so this is no longer
  /// the Lab's old hardcoded literal.
  final String quarterLabel;

  final String homeAbbreviation;
  final String awayAbbreviation;
  final Color homeColor;
  final Color awayColor;

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
              _TeamDot(color: awayColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                awayAbbreviation,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _legibleTextColor(awayColor, theme.brightness),
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
              quarterLabel,
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
                homeAbbreviation,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _legibleTextColor(homeColor, theme.brightness),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _TeamDot(color: homeColor),
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
    required this.homeAbbreviation,
    required this.awayAbbreviation,
    required this.homeColor,
    required this.awayColor,
    required this.homeEmoji,
  });

  final _LabBeat? current;
  final List<_LabBeat> log;

  /// The current playback speed's per-beat interval -- ball-travel
  /// animations scale off it (capped at a sensible max) so a pass/shot
  /// always finishes comfortably within its own beat's time slot,
  /// however fast or slow that is.
  final int intervalMs;

  /// Passed straight through to [_PlayHeadline] -- this panel itself only
  /// reads [homeColor]/[awayColor]/[homeEmoji] directly.
  final String homeAbbreviation;
  final String awayAbbreviation;
  final Color homeColor;
  final Color awayColor;
  final String homeEmoji;

  /// How many of the last plays a blip stays visible for before fading
  /// out completely.
  static const _blipLifetimePlays = 5;

  /// Opacity per trail position (0 = newest) -- a steep initial drop
  /// rather than a straight linear ramp, so the 2nd-newest blip reads as
  /// unmistakably older at a glance. A direct GM catch (2026-08-18):
  /// "because of color changes, sometimes I'm not sure which is the
  /// latest" -- a flat `1 - i/lifetime` ramp only dimmed the very next
  /// blip by 20%, not enough of a break from full brightness once a
  /// different team's color was involved too.
  static const _blipOpacities = [1.0, 0.42, 0.26, 0.14, 0.05];

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
      // 0.5 -> 0.2 (2026-08-18, a direct GM follow-up): "it keeps
      // showing the player within the 3pt arc, which would never
      // happen." 0.5 sat past the arc's own boundary (max ~0.42 at the
      // widest chip position) on paper, but not with enough daylight to
      // read as unambiguously "near mid-court" at a glance -- this
      // leaves real clearance instead of a close call.
      _Zone.midcourt => 0.2,
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

  /// Where a team's basket (the rim itself) sits -- the ball-travel
  /// destination for every shot attempt. Home's is near the right edge,
  /// away's near the left, matching [_blipAlignment]'s own
  /// home-right/away-left convention.
  static Alignment _basketAlignment(_Team team) =>
      Alignment(team == _Team.home ? 0.95 : -0.95, 0.0);

  /// Where an inbound blip sits -- pushed further out than the rim
  /// itself ([_basketAlignment]'s 0.95), right up against the court's
  /// own drawn edge. A direct GM follow-up (2026-08-18): "put the blip
  /// as far to the side as you can. Ideally it'd be a blip out of
  /// bounds under the basket, but if it's just really close to the out
  /// of bounds underneath the basket, I'm cool with that" -- 0.97 is as
  /// close to the edge as it can go without the dot itself starting to
  /// clip off the panel.
  static Alignment _inboundAlignment(_Team team) =>
      Alignment(team == _Team.home ? 0.97 : -0.97, 0.0);

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
                      centerRingColor: homeColor,
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
                  child: Text(homeEmoji, style: const TextStyle(fontSize: 50)),
                ),
                for (var i = 0; i < zoned.length; i++)
                  Align(
                    alignment: zoned[i].isInbound
                        // An inbound blip sits behind the *opposing*
                        // team's basket -- see `_LabBeat.isInbound`'s own
                        // doc comment for why that's actually this
                        // team's own end -- and further out than the rim
                        // itself, see `_inboundAlignment`.
                        ? _inboundAlignment(_opposingTeam(zoned[i].team!))
                        : _blipAlignment(
                            zoned[i].team!,
                            zoned[i].zone!,
                            zoned[i].chipIndex ?? 0,
                          ),
                    child: _BlipDot(
                      key: ValueKey(zoned[i].displayText),
                      color: zoned[i].badgeTeam == _Team.home
                          ? homeColor
                          : awayColor,
                      outlineColor: outline,
                      opacity: _blipOpacities[i],
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
                                      ? homeColor
                                      : awayColor)),
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
        SizedBox(
          height: 116,
          child: _PlayHeadline(
            beat: current,
            homeAbbreviation: homeAbbreviation,
            awayAbbreviation: awayAbbreviation,
            homeColor: homeColor,
            awayColor: awayColor,
          ),
        ),
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
                      beat.badgeTeam == _Team.home ? homeColor : awayColor,
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
  const _PlayHeadline({
    required this.beat,
    required this.homeAbbreviation,
    required this.awayAbbreviation,
    required this.homeColor,
    required this.awayColor,
  });

  final _LabBeat? beat;
  final String homeAbbreviation;
  final String awayAbbreviation;
  final Color homeColor;
  final Color awayColor;

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
          _HighlightBadge(
            team: current.badgeTeam,
            label: label,
            homeAbbreviation: homeAbbreviation,
            awayAbbreviation: awayAbbreviation,
            homeColor: homeColor,
            awayColor: awayColor,
          ),
          const SizedBox(height: 4),
        ] else if (current.isPass) ...[
          Text(
            '${current.badgeTeam == _Team.home ? homeAbbreviation : awayAbbreviation} '
            'Pass',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _legibleTextColor(
                current.badgeTeam == _Team.home ? homeColor : awayColor,
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
  const _HighlightBadge({
    required this.team,
    required this.label,
    required this.homeAbbreviation,
    required this.awayAbbreviation,
    required this.homeColor,
    required this.awayColor,
  });

  final _Team team;
  final String label;
  final String homeAbbreviation;
  final String awayAbbreviation;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    final background = team == _Team.home ? homeColor : awayColor;
    final foreground = background.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;
    final abbreviation = team == _Team.home
        ? homeAbbreviation
        : awayAbbreviation;
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
    required this.offered,
  });

  final String label;
  final String homeAbbreviation;
  final String awayAbbreviation;
  final int homeScore;
  final int awayScore;

  /// The real, already-drawn 3-option menu (2026-08-18, real-game wiring
  /// -- `TODO.md` item 8's live-game architecture stage 4) -- computed
  /// once by whichever `CoachingOptionPicker`/`LiveCoachingPicker` opened
  /// this sheet (`offerCoachingOptions`, applying the real stoppage/
  /// unanswered-run state), not re-rolled here. This sheet just displays
  /// it and returns a pick.
  final List<CoachingOption> offered;

  @override
  State<_CoachingBreakSheet> createState() => _CoachingBreakSheetState();
}

class _CoachingBreakSheetState extends State<_CoachingBreakSheet> {
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
            for (final option in widget.offered) ...[
              if (option != widget.offered.first)
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
