import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/wbl_logo.dart';
import '../franchise/application/current_franchise_provider.dart';
import '../franchise/onboarding/onboarding_screen.dart';
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
/// runs. First real consumer of the league data model — later this becomes
/// standings once a season exists (see `0B_Planned.md`, Phase 2).
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

    return ListView(
      children: [
        const Center(child: WblLogo(size: 72)),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(
          title: Conference.atlantic.label,
          teams: atlantic,
          userTeamAbbreviation: userTeamAbbreviation,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(
          title: Conference.pacific.label,
          teams: pacific,
          userTeamAbbreviation: userTeamAbbreviation,
        ),
      ],
    );
  }
}

class _ConferenceSection extends StatelessWidget {
  const _ConferenceSection({
    required this.title,
    required this.teams,
    required this.userTeamAbbreviation,
  });

  final String title;
  final List<Team> teams;
  final String? userTeamAbbreviation;

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
