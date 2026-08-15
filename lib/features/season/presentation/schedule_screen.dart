import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../generation/all_star_generator.dart' show kAllStarWeek;
import '../generation/season_schedule_generator.dart' show weekLabel;
import 'results_screen.dart';

enum _ScheduleMode { myTeam, fullLeague }

/// The season's schedule -- either the GM's own team's calendar (the
/// original "what's coming up" view `0B_Planned.md`'s League-screens spec
/// called for) or every game leaguewide, grouped by week ("I think we need
/// a schedule screen that shows the schedule for the entire season" -- a
/// direct GM ask, since the original only ever showed one team's games).
/// Read-only either way: nothing here advances the season, it just lists
/// it (`advanceGameDay`/`simulatePostseasonAndPersist` on the Dashboard
/// still own actually playing games).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  var _mode = _ScheduleMode.myTeam;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_ScheduleMode>(
                segments: const [
                  ButtonSegment(
                    value: _ScheduleMode.myTeam,
                    label: Text('My Team'),
                  ),
                  ButtonSegment(
                    value: _ScheduleMode.fullLeague,
                    label: Text('Full League'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _mode == _ScheduleMode.myTeam
                    ? _MyTeamSchedule(franchise: widget.franchise)
                    : _FullLeagueSchedule(franchise: widget.franchise),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _FixtureKey = (int week, GameDay day, String home, String away);

_FixtureKey _fixtureKey(ScheduledGame game) =>
    (game.week, game.day, game.homeTeamAbbreviation, game.awayTeamAbbreviation);

int _byWeekThenDay(ScheduledGame a, ScheduledGame b) {
  final byWeek = a.week.compareTo(b.week);
  if (byWeek != 0) return byWeek;
  return a.day.index.compareTo(b.day.index);
}

/// Whether [game] is one of the 2 synthetic All-Star week placeholders
/// (`all_star_generator.dart`'s `generateAllStarWeekGames`) -- their
/// `homeTeamAbbreviation`/`awayTeamAbbreviation` are made-up conference
/// squad ids (`kAtlanticAllStarsAbbreviation`/`kPacificAllStarsAbbreviation`),
/// never a real league team, so every row builder here has to check this
/// before ever calling [teamByAbbreviation] on either -- that function
/// throws on an unrecognized abbreviation, same as it would for any other
/// made-up one.
bool _isAllStarPlaceholderGame(ScheduledGame game) =>
    game.type == GameType.allStarGame ||
    game.type == GameType.skillsCompetition;

/// A neutral matchup line for an All-Star placeholder row -- no real
/// team names to show (see [_isAllStarPlaceholderGame]'s own doc
/// comment), and no "vs/at" framing either, since it isn't really the
/// GM's own team playing.
const _kAllStarMatchupLabel = 'Atlantic vs. Pacific All-Stars';

class _MyTeamSchedule extends StatelessWidget {
  const _MyTeamSchedule({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final teamAbbreviation = franchise.team.abbreviation;
    final ownGames = [
      for (final game in franchise.seasonProgress.schedule.games)
        // The All-Star week placeholders show up on every team's own
        // calendar, GM's club included -- the whole league sits out its
        // normal games that week, so it belongs here even though neither
        // "team" in the fixture is literally the GM's own (2026-08-11, a
        // direct GM ask -- the break was otherwise invisible on this
        // view entirely, since it never matches the GM's own abbreviation).
        if (game.homeTeamAbbreviation == teamAbbreviation ||
            game.awayTeamAbbreviation == teamAbbreviation ||
            _isAllStarPlaceholderGame(game))
          game,
    ]..sort(_byWeekThenDay);

    // Keyed on (week, day, home, away) rather than game identity -- a
    // reloaded save deserializes fresh `ScheduledGame` objects, so this is
    // the only reliable way to match a played result back to its fixture.
    // A team plays at most one game per game day, so this key is unique
    // per team even without the type/round in it.
    final playedByFixture = {
      for (final played in franchise.seasonProgress.playedGames)
        _fixtureKey(played.game): played,
    };

    if (ownGames.isEmpty) {
      return const Center(child: Text('No games scheduled yet.'));
    }
    return ListView(
      children: [
        for (var i = 0; i < ownGames.length; i++) ...[
          _MyTeamRow(
            franchise: franchise,
            game: ownGames[i],
            played: playedByFixture[_fixtureKey(ownGames[i])],
          ),
          if (i != ownGames.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MyTeamRow extends StatelessWidget {
  const _MyTeamRow({
    required this.franchise,
    required this.game,
    required this.played,
  });

  final Franchise franchise;
  final ScheduledGame game;
  final PlayedGame? played;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllStar = _isAllStarPlaceholderGame(game);
    final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
    final played = this.played;

    Widget matchup;
    if (isAllStar) {
      matchup = Text(_kAllStarMatchupLabel, style: theme.textTheme.bodyLarge);
    } else {
      final opponentAbbreviation = isHome
          ? game.awayTeamAbbreviation
          : game.homeTeamAbbreviation;
      final opponent = teamByAbbreviation(franchise, opponentAbbreviation);
      matchup = Text(
        '${isHome ? 'vs' : 'at'} ${opponent.emoji} ${opponent.name}',
        style: theme.textTheme.bodyLarge,
      );
    }

    final row = Row(
      children: [
        _ScheduleDateColumn(week: game.week, day: game.day),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              matchup,
              _TypeLabel(game: game),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // The All-Star placeholder squads have no "GM's own team won/lost"
        // outcome to report -- the real result lives on the dedicated
        // result screens (reachable from Mail), not here.
        if (isAllStar)
          Text(
            played == null ? 'Upcoming' : 'Played',
            style: theme.textTheme.bodySmall,
          )
        else
          _ResultLabel(isHome: isHome, played: played),
      ],
    );

    // Only a played, non-placeholder game has a real box score to link to
    // -- `teamByAbbreviation` (which `PlayedGameDetailScreen` also needs)
    // would throw on the All-Star squads' made-up abbreviations.
    if (played == null || isAllStar) return AppCard(child: row);
    return AppCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PlayedGameDetailScreen(franchise: franchise, played: played),
            ),
          );
        },
        child: row,
      ),
    );
  }
}

/// The 3-line date column every schedule row (both My Team and Full
/// League) leads with: the full fictional date, the abbreviated weekday,
/// and the game week number -- e.g. "May 3" / "Thu" / "Week 4". Used to
/// be just [GameDay.label] alone in the Full League row, which wrapped
/// to two lines in a too-narrow column (a direct GM report, 2026-08-15),
/// and didn't show the week number at all -- a second direct ask in the
/// same report ("full league schedule needs to show what game week it
/// is"). Fixed width plus `maxLines: 1` on every line keeps all three
/// single-line even at larger text-scale settings.
class _ScheduleDateColumn extends StatelessWidget {
  const _ScheduleDateColumn({required this.week, required this.day});

  final int week;
  final GameDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatFictionalDate(week, day),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            day.shortLabel,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            weekLabel(week),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TypeLabel extends StatelessWidget {
  const _TypeLabel({required this.game});

  final ScheduledGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPreseason = game.type == GameType.preseason;
    final isContinentalCup = game.type == GameType.continentalCup;
    // All-Star week gets the same unmissable treatment as Preseason/Cup
    // (2026-08-11, a direct GM ask -- the break was otherwise
    // indistinguishable from any other week on this screen).
    final isAllStarBreak = _isAllStarPlaceholderGame(game);
    // Cup games get the same unmissable treatment as Preseason -- just
    // "🏆 WBL Continental Cup", no round number (2026-08-07, a direct GM
    // ask). The round is still visible via the League screen's own Cup
    // tab, which already groups games under a real round header.
    final label = isContinentalCup
        ? '🏆 WBL Continental Cup'
        : isAllStarBreak
        ? '⭐ ${game.typeLabel}'
        : game.typeLabel;
    final isCalledOut = isPreseason || isContinentalCup || isAllStarBreak;
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: isCalledOut ? theme.colorScheme.primary : null,
        fontWeight: isCalledOut ? FontWeight.bold : null,
      ),
    );
  }
}

class _ResultLabel extends StatelessWidget {
  const _ResultLabel({required this.isHome, required this.played});

  final bool isHome;
  final PlayedGame? played;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final played = this.played;
    if (played == null) {
      return Text('Upcoming', style: theme.textTheme.bodySmall);
    }

    final ownScore = isHome ? played.homeScore : played.awayScore;
    final opponentScore = isHome ? played.awayScore : played.homeScore;
    final won = ownScore > opponentScore;
    final color = won ? Colors.green.shade700 : Colors.red.shade700;

    return Text(
      // The W/L letter, not color alone, carries the outcome
      // (accessibility rule in ARCHITECTURE.md).
      '${won ? 'W' : 'L'} $ownScore-$opponentScore',
      style: theme.textTheme.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// One flattened item in the Full League list -- either a week's section
/// header or one of that week's games -- so the whole grouped view can
/// still ride a single `ListView.builder` (a full season runs to 300+
/// games leaguewide, same "don't lay out everything at once" reasoning
/// `ResultsScreen` already established).
sealed class _LeagueListItem {}

class _WeekHeaderItem extends _LeagueListItem {
  _WeekHeaderItem(this.week);
  final int week;
}

class _GameItem extends _LeagueListItem {
  _GameItem(this.game, this.played);
  final ScheduledGame game;
  final PlayedGame? played;
}

class _FullLeagueSchedule extends StatelessWidget {
  const _FullLeagueSchedule({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final games = [...franchise.seasonProgress.schedule.games]
      ..sort(_byWeekThenDay);
    if (games.isEmpty) {
      return const Center(child: Text('No games scheduled yet.'));
    }

    final playedByFixture = {
      for (final played in franchise.seasonProgress.playedGames)
        _fixtureKey(played.game): played,
    };

    final items = <_LeagueListItem>[];
    int? currentWeek;
    for (final game in games) {
      if (game.week != currentWeek) {
        currentWeek = game.week;
        items.add(_WeekHeaderItem(game.week));
      }
      items.add(_GameItem(game, playedByFixture[_fixtureKey(game)]));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _WeekHeaderItem() => _WeekHeader(week: item.week),
          _GameItem() => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _LeagueGameRow(
              franchise: franchise,
              game: item.game,
              played: item.played,
            ),
          ),
        };
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.week});

  final int week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Called out the same way individual All-Star games already are
    // (2026-08-11, a direct GM ask) -- the week header itself should say
    // so too, not just the games underneath it.
    final label = week == kAllStarWeek
        ? '${weekLabel(week)} · ⭐ All-Star Break'
        : weekLabel(week);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _LeagueGameRow extends StatelessWidget {
  const _LeagueGameRow({
    required this.franchise,
    required this.game,
    required this.played,
  });

  final Franchise franchise;
  final ScheduledGame game;
  final PlayedGame? played;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllStar = _isAllStarPlaceholderGame(game);
    final played = this.played;

    // `teamByAbbreviation` throws on the All-Star squads' made-up
    // abbreviations -- see `_isAllStarPlaceholderGame`'s own doc comment.
    Widget matchup;
    bool homeWon;
    if (isAllStar) {
      matchup = Text(_kAllStarMatchupLabel, style: theme.textTheme.bodyMedium);
      homeWon = false;
    } else {
      final homeTeam = teamByAbbreviation(franchise, game.homeTeamAbbreviation);
      final awayTeam = teamByAbbreviation(franchise, game.awayTeamAbbreviation);
      matchup = Text(
        '${awayTeam.emoji} ${awayTeam.name} @ ${homeTeam.emoji} ${homeTeam.name}',
        style: theme.textTheme.bodyMedium,
      );
      homeWon = played != null && played.homeScore > played.awayScore;
    }

    final row = Row(
      children: [
        _ScheduleDateColumn(week: game.week, day: game.day),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              matchup,
              _TypeLabel(game: game),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Same "no GM-own-team outcome to report" reasoning as
        // `_MyTeamRow` -- the real result lives on the dedicated result
        // screens (reachable from Mail), not here.
        if (isAllStar)
          Text(
            played == null ? 'Upcoming' : 'Played',
            style: theme.textTheme.bodySmall,
          )
        else if (played == null)
          Text('Upcoming', style: theme.textTheme.bodySmall)
        else
          Text(
            '${played.awayScore}-${played.homeScore}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: homeWon ? FontWeight.normal : FontWeight.bold,
            ),
          ),
      ],
    );

    if (played == null || isAllStar) return AppCard(child: row);
    return AppCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PlayedGameDetailScreen(franchise: franchise, played: played),
            ),
          );
        },
        child: row,
      ),
    );
  }
}
