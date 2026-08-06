import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';

/// Every game on the GM's own team's calendar this season, in chronological
/// order -- the "what's coming up" view `0B_Planned.md`'s League-screens
/// spec calls for, previously built on the backend (`SeasonSchedule`) with
/// no screen to show it. Read-only: nothing here advances the season, it
/// just lists it (`advanceGameDay`/`simulatePostseasonAndPersist` on the
/// Dashboard still own actually playing games).
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final teamAbbreviation = franchise.team.abbreviation;
    final ownGames = [
      for (final game in franchise.seasonProgress.schedule.games)
        if (game.homeTeamAbbreviation == teamAbbreviation ||
            game.awayTeamAbbreviation == teamAbbreviation)
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

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SafeArea(
        child: ownGames.isEmpty
            ? const Center(child: Text('No games scheduled yet.'))
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  for (var i = 0; i < ownGames.length; i++) ...[
                    _ScheduleRow(
                      franchise: franchise,
                      game: ownGames[i],
                      played: playedByFixture[_fixtureKey(ownGames[i])],
                    ),
                    if (i != ownGames.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
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

/// "Preseason" / "Regular Season" / a named Continental Cup or postseason
/// round -- UI-only formatting, not worth a domain-level label extension
/// for round-number-to-name mapping that nothing outside this screen needs
/// yet.
String _gameTypeLabel(ScheduledGame game) {
  return switch (game.type) {
    GameType.preseason => 'Preseason',
    GameType.regularSeason => 'Regular Season',
    GameType.continentalCup => switch (game.continentalCupRound!) {
      1 => 'Continental Cup Rd. 1',
      2 => 'Continental Cup Rd. 2',
      3 => 'Continental Cup Quarterfinals',
      4 => 'Continental Cup Semifinals',
      _ => 'Continental Cup Final',
    },
    GameType.postseason => switch (game.postseasonRound!) {
      1 => 'Postseason First Round',
      2 => 'Postseason Semifinals',
      _ => 'Postseason Finals',
    },
  };
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
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
    final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
    final opponentAbbreviation = isHome
        ? game.awayTeamAbbreviation
        : game.homeTeamAbbreviation;
    final opponent = teamByAbbreviation(franchise, opponentAbbreviation);

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Week ${game.week}', style: theme.textTheme.bodyMedium),
                Text(game.day.label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isHome ? 'vs' : 'at'} ${opponent.emoji} ${opponent.name}',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(_gameTypeLabel(game), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ResultLabel(franchise: franchise, isHome: isHome, played: played),
        ],
      ),
    );
  }
}

class _ResultLabel extends StatelessWidget {
  const _ResultLabel({
    required this.franchise,
    required this.isHome,
    required this.played,
  });

  final Franchise franchise;
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
