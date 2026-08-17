import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../app/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/onboarding/quick_start_teams.dart';
import '../../matchup/domain/defensive_tactic.dart';

/// Which team (if any) a [_LabBeat] belongs to -- `null` for a neutral
/// beat like the opening tip-off.
enum _Team { home, away }

/// Which zone (if any) a [_LabBeat]'s action happened in -- drives where
/// a blip lands. `null` for a non-shot beat.
enum _Zone { paint, arc }

/// Playback speed for the scripted beat sequence -- a `SegmentedButton`
/// picker (2026-08-17, a direct GM ask), same pattern the Settings theme
/// picker already uses. Intervals slid slower on a same-session
/// follow-up ask ("let's slide those speed a little") -- the first pass
/// (1.8s/1.1s/0.55s) read as too fast to actually read a play.
enum _Speed { slow, medium, fast }

int _intervalMsFor(_Speed speed) => switch (speed) {
  _Speed.slow => 3000,
  _Speed.medium => 2000,
  _Speed.fast => 750,
};

/// A notable play worth calling out with a colored keyword badge --
/// "keywords that stand out" (2026-08-17, a direct GM ask), deliberately
/// reserved for genuine highlights (three-pointers, and-ones, steals,
/// blocks) rather than every single basket, so the badge stays
/// meaningful instead of becoming visual noise.
enum _Highlight { none, threePointer, andOne, steal, block }

extension on _Highlight {
  String? get label => switch (this) {
    _Highlight.none => null,
    _Highlight.threePointer => '3PTS',
    _Highlight.andOne => 'AND-1',
    _Highlight.steal => 'STEAL',
    _Highlight.block => 'BLOCK',
  };
}

/// One scripted beat in the mock possession sequence -- hand-written
/// flavor text, not real engine output, so pacing/wording can be tuned
/// directly rather than filtered out of a much noisier real
/// `MatchEvent` log. Wiring this to a real `simulateMatch` result is a
/// natural follow-up once the visual itself is settled.
class _LabBeat {
  const _LabBeat({
    required this.team,
    this.zone,
    this.chipIndex,
    this.creditTeam,
    required this.playerName,
    required this.playerNumber,
    required this.playerPosition,
    required this.action,
    this.highlight = _Highlight.none,
    this.deltaHome = 0,
    this.deltaAway = 0,
    required this.clockSeconds,
    this.isBreak = false,
    this.breakLabel,
  });

  /// Whose attacking end this happened at -- drives the blip's
  /// left/right position. `null` only for the tip-off, which has no
  /// attacking end yet.
  final _Team? team;
  final _Zone? zone;

  /// Which of 5 candidate slots within a zone the blip spawns at.
  final int? chipIndex;

  /// Who gets credit for this beat -- the badge, the blip's color, and
  /// the "(POS TEAM)" tag all read off this. Defaults to [team]; only
  /// ever overridden for a defensive highlight (a block/steal), where
  /// the play still happens at the *offense's* end ([team]) but the
  /// credited player is on the other side -- see [badgeTeam].
  final _Team? creditTeam;

  final String playerName;
  final int playerNumber;
  final String playerPosition;

  /// The action phrase after the player tag, e.g. "drives and scores."
  final String action;
  final _Highlight highlight;
  final int deltaHome;
  final int deltaAway;
  final int clockSeconds;
  final bool isBreak;
  final String? breakLabel;

  _Team get badgeTeam => creditTeam ?? team ?? _Team.home;

  /// "#4 Castellano (PG DSM) drives and scores." -- a direct GM ask
  /// (2026-08-17): "when naming a player, instead of 'Castellano drives
  /// and scores', it should be like '#42 Castellano (PF DSM) drives and
  /// scores.'"
  String get displayText {
    final abbreviation = badgeTeam == _Team.home
        ? _homeTeam.abbreviation
        : _awayTeam.abbreviation;
    return '#$playerNumber $playerName ($playerPosition $abbreviation) '
        '$action';
  }
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
/// feel real, not a placeholder like "Player 1."
const _beats = <_LabBeat>[
  _LabBeat(
    team: null,
    creditTeam: _Team.home,
    playerName: 'Castellano',
    playerNumber: 4,
    playerPosition: 'PG',
    action: 'wins the tip for Des Moines.',
    clockSeconds: 600,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 0,
    playerName: 'Castellano',
    playerNumber: 4,
    playerPosition: 'PG',
    action: 'drives and scores.',
    deltaHome: 2,
    clockSeconds: 586,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.arc,
    chipIndex: 4,
    playerName: 'Chen',
    playerNumber: 8,
    playerPosition: 'SG',
    action: 'buries the three off the catch!',
    highlight: _Highlight.threePointer,
    deltaAway: 3,
    clockSeconds: 570,
  ),
  _LabBeat(
    team: _Team.home,
    creditTeam: _Team.away,
    zone: _Zone.paint,
    chipIndex: 2,
    playerName: 'Petrov',
    playerNumber: 55,
    playerPosition: 'C',
    action: "swats away Whitfield's shot at the rim!",
    highlight: _Highlight.block,
    clockSeconds: 558,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.paint,
    chipIndex: 0,
    playerName: 'Holloway',
    playerNumber: 14,
    playerPosition: 'SF',
    action: 'drives, fouled -- 2 for 2 at the line.',
    deltaAway: 2,
    clockSeconds: 548,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 2,
    playerName: 'Okonkwo',
    playerNumber: 21,
    playerPosition: 'PF',
    action: "cleans up the putback after Vasquez's three rims out.",
    deltaHome: 2,
    clockSeconds: 530,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.arc,
    chipIndex: 1,
    playerName: 'Tuiasosopo',
    playerNumber: 32,
    playerPosition: 'PF',
    action: 'jumper is off the mark, Des Moines ball.',
    clockSeconds: 515,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 0,
    playerName: 'Castellano',
    playerNumber: 4,
    playerPosition: 'PG',
    action: 'scores through contact -- and-one!',
    highlight: _Highlight.andOne,
    deltaHome: 3,
    clockSeconds: 502,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.paint,
    chipIndex: 2,
    playerName: 'Petrov',
    playerNumber: 55,
    playerPosition: 'C',
    action: 'overpowers inside for two.',
    deltaAway: 2,
    clockSeconds: 491,
  ),
  _LabBeat(
    team: _Team.away,
    creditTeam: _Team.home,
    zone: _Zone.arc,
    chipIndex: 1,
    playerName: 'Vasquez',
    playerNumber: 11,
    playerPosition: 'SG',
    action: 'tips the pass away -- Des Moines recovers!',
    highlight: _Highlight.steal,
    clockSeconds: 478,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.arc,
    chipIndex: 4,
    playerName: 'Marsh',
    playerNumber: 23,
    playerPosition: 'SF',
    action: 'drills a corner three!',
    highlight: _Highlight.threePointer,
    deltaHome: 3,
    clockSeconds: 462,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.arc,
    chipIndex: 3,
    playerName: 'Chen',
    playerNumber: 8,
    playerPosition: 'SG',
    action: 'buries another off a Reyes feed -- Kansas City answers!',
    highlight: _Highlight.threePointer,
    deltaAway: 3,
    clockSeconds: 446,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.paint,
    chipIndex: 2,
    playerName: 'Okonkwo',
    playerNumber: 21,
    playerPosition: 'PF',
    action: 'backs down her defender, scores inside.',
    deltaHome: 2,
    clockSeconds: 429,
  ),
  _LabBeat(
    team: _Team.away,
    zone: _Zone.paint,
    chipIndex: 0,
    playerName: 'Holloway',
    playerNumber: 14,
    playerPosition: 'SF',
    action: "floater falls short, Des Moines rebounds.",
    clockSeconds: 408,
  ),
  _LabBeat(
    team: _Team.home,
    zone: _Zone.arc,
    chipIndex: 1,
    playerName: 'Castellano',
    playerNumber: 4,
    playerPosition: 'PG',
    action:
        'pulls up from deep at the buzzer -- good! End of the quarter.',
    highlight: _Highlight.threePointer,
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
/// The coaching-break sheet (a single real [DefensiveTactic] re-pick,
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

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _step() {
    final nextIndex = _index + 1;
    if (nextIndex >= _beats.length) {
      _stop();
      return;
    }
    final beat = _beats[nextIndex];
    setState(() {
      _index = nextIndex;
      _home += beat.deltaHome;
      _away += beat.deltaAway;
      _tickerLog.insert(0, beat);
    });
    if (beat.isBreak) {
      _stop();
      _openBreak(beat.breakLabel ?? 'COACHING BREAK');
    }
  }

  Future<void> _openBreak(String label) async {
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
    await showModalBottomSheet<DefensiveTactic>(
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
        ),
      ),
    );
    // The picked tactic is discarded here -- this lab has no live match
    // to resume into. A real implementation would feed it back into the
    // resumed segment's DefensiveTactic param (`match_engine.dart`).
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
                    possessionTeam: _currentBeat?.team,
                  ),
                  const Divider(height: AppSpacing.lg),
                  SizedBox(
                    height: 360,
                    child: _FullCourtPanel(
                      current: _currentBeat,
                      log: _tickerLog,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _playing ? _stop : _play,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  label: Text(_playing ? 'Pause' : 'Play'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SegmentedButton<_Speed>(
                    segments: const [
                      ButtonSegment(value: _Speed.slow, label: Text('Slow')),
                      ButtonSegment(value: _Speed.medium, label: Text('Med')),
                      ButtonSegment(value: _Speed.fast, label: Text('Fast')),
                    ],
                    selected: {_speed},
                    onSelectionChanged: (selection) {
                      setState(() => _speed = selection.first);
                      if (_playing) {
                        _stop();
                        _play();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _openBreak('PREVIEW'),
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
              text: 'Highlight badges -- team-color background, computed '
                  'black/white text for guaranteed contrast. Toggle '
                  'Light/Dark above: does DSM green / KCY navy hold up '
                  'in both, or does the badge itself need a theme-aware '
                  'tint (not just the text)?',
            ),
            const _QuestionItem(
              text: 'The wood floor is dark-mode-only right now (light '
                  'mode stays plain, matching the court.svg reference) '
                  '-- want it in light mode too, or does the plain floor '
                  'read better there?',
            ),
            const _QuestionItem(
              text: 'Slow/Med/Fast are now 3.0s/2.0s/0.75s per beat -- '
                  'right range now, or still needs a slide?',
            ),
            const _QuestionItem(
              text: 'The break sheet itself -- right height/weight for a '
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
    required this.possessionTeam,
  });

  final int homeScore;
  final int awayScore;
  final String clockLabel;

  /// Who currently has the ball -- a direct GM ask (2026-08-17): "can we
  /// have an emoji for who has the ball currently?" `null` before the
  /// tip-off resolves.
  final _Team? possessionTeam;

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
              if (possessionTeam == _Team.away) ...[
                const SizedBox(width: 3),
                const Text('🏀', style: TextStyle(fontSize: 14)),
              ],
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
              if (possessionTeam == _Team.home) ...[
                const Text('🏀', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 3),
              ],
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
  const _FullCourtPanel({required this.current, required this.log});

  final _LabBeat? current;
  final List<_LabBeat> log;

  /// How many of the last plays a blip stays visible for before fading
  /// out completely.
  static const _blipLifetimePlays = 5;

  /// y-offset per [_LabBeat.chipIndex] (0-4), spreading blips up/down
  /// within whichever zone they land in rather than stacking on one
  /// point.
  static const _yOffsets = [-0.55, -0.22, 0.0, 0.22, 0.55];

  static Alignment _blipAlignment(_Team team, _Zone zone, int chipIndex) {
    final y = _yOffsets[chipIndex % _yOffsets.length];
    final magnitude = zone == _Zone.paint ? 0.86 : 0.42;
    // Home attacks the right (positive x), away attacks the left.
    final x = team == _Team.home ? magnitude : -magnitude;
    return Alignment(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final outline = isDark ? Colors.white : Colors.black;
    // A nice woody pine/walnut floor in dark mode (a direct GM ask,
    // 2026-08-17) -- light mode stays the plain floor from the
    // court.svg reference; only dark mode asked for the wood look.
    final floorColor = isDark ? const Color(0xFF4E3524) : null;
    final lineColor = isDark
        ? const Color(0xFFE8D9C3)
        : theme.colorScheme.outlineVariant;
    final zoned = log
        .where((b) => b.zone != null && b.team != null)
        .take(_blipLifetimePlays)
        .toList();
    final recent = log.take(3).toList();

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
                  // 3x the original size (2026-08-17, a direct GM ask) --
                  // the center-court ring below is sized to match.
                  child: Text(
                    _homeEmoji,
                    style: const TextStyle(fontSize: 66),
                  ),
                ),
                for (var i = 0; i < zoned.length; i++)
                  Align(
                    alignment: _blipAlignment(
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
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PlayHeadline(beat: current),
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

/// The current play's headline -- a colored keyword badge above the
/// "#N Name (POS TEAM) action" line for a notable play
/// ([_LabBeat.highlight] != none), or just the plain line otherwise.
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
        ],
        Text(
          current.displayText,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
        : Rect.fromLTWH(4, (size.height - laneHeight) / 2, laneWidth, laneHeight);
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
      Rect.fromCircle(center: Offset(basketX, size.height / 2), radius: threePointRadius),
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

    // A center-court "floor decal" -- a faint tinted disc plus a ring in
    // the home team's color, doing double duty as the reference's plain
    // half-court circle. Sized to comfortably frame the 3x-larger center
    // emoji (see _FullCourtPanel) rather than the emoji overflowing it.
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
        ..color = centerRingColor.withValues(alpha: 0.65)
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

/// The coaching-break sheet -- a real [DefensiveTactic] re-pick (the one
/// lever already wired into the engine), hard-stop (`isDismissible:
/// false`, `enableDrag: false`) so it always waits for an explicit
/// "Resume Game" tap.
class _CoachingBreakSheet extends StatefulWidget {
  const _CoachingBreakSheet({
    required this.label,
    required this.homeAbbreviation,
    required this.awayAbbreviation,
    required this.homeScore,
    required this.awayScore,
  });

  final String label;
  final String homeAbbreviation;
  final String awayAbbreviation;
  final int homeScore;
  final int awayScore;

  @override
  State<_CoachingBreakSheet> createState() => _CoachingBreakSheetState();
}

class _CoachingBreakSheetState extends State<_CoachingBreakSheet> {
  var _tactic = DefensiveTactic.balanced;

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
              'Defensive Tactic -- the one lever already wired into the '
              'engine. The fuller catalog (fatigue-aware rest calls, '
              'momentum plays, pace changes) is its own design pass, '
              'once this shell is settled.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final tactic in DefensiveTactic.values) ...[
              if (tactic != DefensiveTactic.values.first)
                const SizedBox(height: AppSpacing.xs),
              _LabTacticOption(
                tactic: tactic,
                isSelected: tactic == _tactic,
                onTap: () => setState(() => _tactic = tactic),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_tactic),
              child: const Text('Resume Game'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabTacticOption extends StatelessWidget {
  const _LabTacticOption({
    required this.tactic,
    required this.isSelected,
    required this.onTap,
  });

  final DefensiveTactic tactic;
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
                    tactic.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tactic.shorthand,
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
