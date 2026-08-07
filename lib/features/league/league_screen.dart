import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/wbl_logo.dart';
import '../franchise/application/current_franchise_provider.dart';
import '../franchise/onboarding/onboarding_screen.dart';
import '../roster/domain/team_overall.dart';
import '../season/application/franchise_rosters.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import '../season/presentation/results_screen.dart';
import '../season/presentation/schedule_screen.dart';
import 'domain/league_draw.dart';
import 'domain/team.dart';
import 'team_row.dart';

/// This playthrough's 20-team league (drawn from the 40-team design pool
/// via `drawLeagueTeams`, keyed on the franchise's `simulationSeed`),
/// grouped by conference, with the GM's own club substituted in for
/// whichever drawn team it replaced (see
/// `Franchise.replacedTeamAbbreviation`) — so the league genuinely reads as
/// 19 AI teams + 1 GM team, not the replaced team plus an unrelated 21st
/// club. There's no franchise (and so no league draw) until onboarding
/// runs. Ranked by regular-season record within each conference
/// (`currentStandings`) once games have been played -- teams that haven't
/// played yet sort to the bottom of their conference, alphabetically.
class LeagueScreen extends ConsumerWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchise = ref.watch(currentFranchiseProvider).value;
    if (franchise == null) {
      return EmptyStateView(
        icon: Icons.emoji_events_outlined,
        message: 'Create an expansion franchise to see your league.',
        action: FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
          },
          child: const Text('Create Expansion Franchise'),
        ),
      );
    }

    final drawnTeams = drawLeagueTeams(
      Random(franchise.simulationSeed + kLeagueDrawSeedOffset),
    );
    final teams = [
      for (final team in drawnTeams)
        if (team.abbreviation == franchise.replacedTeamAbbreviation)
          franchise.team
        else
          team,
    ];

    final atlantic = teams
        .where((team) => team.conference == Conference.atlantic)
        .toList();
    final pacific = teams
        .where((team) => team.conference == Conference.pacific)
        .toList();
    final userTeamAbbreviation = franchise.team.abbreviation;
    final standings = currentStandings(franchise.seasonProgress, teams);
    final rosters = rostersByAbbreviation(franchise);
    final overallByAbbreviation = {
      for (final entry in rosters.entries)
        entry.key: teamOverallForPlayers(entry.value),
    };

    return ListView(
      children: [
        const Center(child: WblLogo(size: 144)),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduleScreen(franchise: franchise),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Schedule'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResultsScreen(franchise: franchise),
                    ),
                  );
                },
                icon: const Icon(Icons.scoreboard_outlined),
                label: const Text('Results'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(
          title: Conference.atlantic.label,
          teams: _rankedByStandings(atlantic, standings),
          standings: standings,
          userTeamAbbreviation: userTeamAbbreviation,
          overallByAbbreviation: overallByAbbreviation,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(
          title: Conference.pacific.label,
          teams: _rankedByStandings(pacific, standings),
          standings: standings,
          userTeamAbbreviation: userTeamAbbreviation,
          overallByAbbreviation: overallByAbbreviation,
        ),
      ],
    );
  }
}

/// [conferenceTeams] sorted best-to-worst by [standings]' order -- teams
/// with no entry there (no regular-season games played yet) sort after
/// every ranked team, alphabetically among themselves.
List<Team> _rankedByStandings(
  List<Team> conferenceTeams,
  List<StandingsEntry> standings,
) {
  final rankIndex = {
    for (var i = 0; i < standings.length; i++) standings[i].teamAbbreviation: i,
  };
  final sorted = [...conferenceTeams];
  sorted.sort((a, b) {
    final aRank = rankIndex[a.abbreviation] ?? standings.length;
    final bRank = rankIndex[b.abbreviation] ?? standings.length;
    final byRank = aRank.compareTo(bRank);
    if (byRank != 0) return byRank;
    return a.abbreviation.compareTo(b.abbreviation);
  });
  return sorted;
}

class _ConferenceSection extends StatelessWidget {
  const _ConferenceSection({
    required this.title,
    required this.teams,
    required this.standings,
    required this.userTeamAbbreviation,
    required this.overallByAbbreviation,
  });

  final String title;
  final List<Team> teams;
  final List<StandingsEntry> standings;
  final String? userTeamAbbreviation;
  final Map<String, int> overallByAbbreviation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < teams.length; i++) ...[
                TeamRow(
                  team: teams[i],
                  isUserTeam: teams[i].abbreviation == userTeamAbbreviation,
                  rank: i + 1,
                  record: recordFor(teams[i].abbreviation, standings),
                  overall: overallByAbbreviation[teams[i].abbreviation],
                ),
                if (i != teams.length - 1) const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
