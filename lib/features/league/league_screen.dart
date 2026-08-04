import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import 'domain/initial_league.dart';
import 'domain/team.dart';

/// Lists the 20-team league template, grouped by conference. First real
/// consumer of the league data model — later this becomes standings once a
/// season exists.
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
        _ConferenceSection(title: 'Atlantic Conference', teams: atlantic),
        const SizedBox(height: AppSpacing.lg),
        _ConferenceSection(title: 'Pacific Conference', teams: pacific),
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
                _TeamRow(team: teams[i]),
                if (i != teams.length - 1) const Divider(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Decorative only — the team name text next to it already
          // carries the information, so this doesn't need its own label.
          ExcludeSemantics(
            child: _ColorSwatch(
              color: team.colors.primary,
              borderColor: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: theme.textTheme.bodyLarge),
                Text(
                  '${team.abbreviation} · ${team.location}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({this.color, this.borderColor});

  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
    );
  }
}
