import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../coach/domain/coach.dart';
import '../coach/domain/coach_archetype.dart';
import '../franchise/domain/franchise.dart';
import '../player/domain/player.dart';
import '../player/presentation/player_detail_screen.dart';
import '../roster/domain/roster_status.dart';
import '../roster/domain/team_overall.dart';
import '../season/application/franchise_rosters.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import 'domain/team_identity.dart';

/// One AI team's real detail page -- current head coach, roster, record,
/// and style -- reached by tapping a team in the League standings
/// (2026-08-20, a direct GM ask: "should be referenced if I click on
/// their team in the league screens... show current head coach, their
/// roster, their record, and their style. I don't know if we've built
/// team-detail pages, yet"). Confirmed while scoping team identities:
/// nothing like this existed before -- `TeamRow` had no tap handler at
/// all anywhere it was used.
///
/// AI-only -- the GM's own row in `LeagueScreen` never wires an `onTap`
/// through to this at all, since `TeamRosterScreen` (the Team tab) is
/// already the real, richer detail screen for the GM's own club, and this
/// screen's coach summary deliberately omits every field that's real for
/// the GM's own coach but permanently, misleadingly `0` for any AI
/// coach -- `Coach.seasonsAsHeadCoach`/`careerWins`/`careerLosses`/
/// `championshipsWon` are all explicitly GM-own-coach-only (see
/// [Coach]'s own doc comments); this screen shows `AiTeamRoster.coachHiredSeason`
/// instead, the one piece of real coaching-tenure data every AI team
/// actually has.
class TeamDetailScreen extends StatelessWidget {
  const TeamDetailScreen({
    required this.franchise,
    required this.teamAbbreviation,
    super.key,
  });

  final Franchise franchise;
  final String teamAbbreviation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final team = teamByAbbreviation(franchise, teamAbbreviation);
    final aiTeam = franchise.league.aiTeams.firstWhere(
      (t) => t.team.abbreviation == teamAbbreviation,
    );
    final coach = aiTeam.coach;
    final roster =
        rostersByAbbreviation(franchise)[teamAbbreviation] ?? const <Player>[];
    final active =
        aiTeam.roster.where((m) => m.status == RosterStatus.active).toList()
          ..sort(
            (a, b) =>
                b.player.ratings.overall.compareTo(a.player.ratings.overall),
          );
    final standings = currentStandings(
      franchise.seasonProgress,
      allLeagueTeams(franchise),
    );
    final record = recordFor(teamAbbreviation, standings);
    final identity = identityFor(teamAbbreviation);
    final tenureSeasons = franchise.season - aiTeam.coachHiredSeason + 1;

    return Scaffold(
      appBar: AppBar(title: Text(team.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${team.emoji} ${team.name}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${record.wins}-${record.losses}'
                    '${record.gamesPlayed == 0 ? ' (no games played yet)' : ''}'
                    ' -- ${teamOverallForPlayers(roster)} OVR',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    identity.styleLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CoachCard(coach: coach, tenureSeasons: tenureSeasons),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Active Roster (${active.length})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < active.length; i++) ...[
                    _RosterRow(franchise: franchise, player: active[i].player),
                    if (i != active.length - 1)
                      const Divider(height: AppSpacing.lg),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach, required this.tenureSeasons});

  final Coach coach;
  final int tenureSeasons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Head Coach', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            coach.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${coach.archetype.label} -- age ${coach.age} -- '
            '$tenureSeasons season${tenureSeasons == 1 ? '' : 's'} with '
            'this club',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _CoachStatChip(label: 'OFF', value: coach.stats.offense),
              _CoachStatChip(label: 'DEF', value: coach.stats.defense),
              _CoachStatChip(label: 'DEV', value: coach.stats.development),
              _CoachStatChip(label: 'MOT', value: coach.stats.motivation),
              _CoachStatChip(label: 'MGT', value: coach.stats.management),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachStatChip extends StatelessWidget {
  const _CoachStatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label $value', style: theme.textTheme.labelSmall),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.franchise, required this.player});

  final Franchise franchise;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jersey = player.jerseyNumber != null
        ? '#${player.jerseyNumber} '
        : '';
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlayerDetailScreen(franchise: franchise, playerId: player.id),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              player.primaryPosition.abbreviation,
              style: theme.textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(
              '$jersey${player.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${player.ratings.overall} OVR',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
