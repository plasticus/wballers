import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import 'domain/initial_league.dart';
import 'domain/team.dart';
import 'team_row.dart';

/// Lists the 20-team league template, grouped by conference. First real
/// consumer of the league data model — later this becomes standings once a
/// season exists (see `FLUTTER_APP_PLAN.md`, Phase 2).
class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final atlantic = kInitialLeagueTeams
        .where((team) => team.conference == Conference.atlantic)
        .toList();
    final pacific = kInitialLeagueTeams
        .where((team) => team.conference == Conference.pacific)
        .toList();

    return ListView(
      children: [
        _ConferenceSection(title: Conference.atlantic.label, teams: atlantic),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(title: Conference.pacific.label, teams: pacific),
      ],
    );
  }
}

class _ConferenceSection extends StatelessWidget {
  const _ConferenceSection({required this.title, required this.teams});

  final String title;
  final List<Team> teams;

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
                TeamRow(team: teams[i]),
                if (i != teams.length - 1) const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
