import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../training/presentation/how_training_works_card.dart';

/// A plain-language reference doc, reachable from the app's main
/// navigation chrome (2026-08-19, a direct GM ask: "we should probably
/// also start building some kind of informational doc that's accessible
/// via the main menu"). Static content only -- no `Franchise` dependency,
/// unlike almost every other screen in this app -- since what a coaching
/// stat does or how training works doesn't change save to save. Meant to
/// grow section by section over time; today covers Coaching and Training,
/// the 2 the GM asked for first.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Guide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            _CoachingSection(),
            SizedBox(height: AppSpacing.md),
            HowTrainingWorksCard(),
          ],
        ),
      ),
    );
  }
}

/// What each of a coach's 5 stats actually does, today -- deliberately
/// brief (a sentence each, a direct GM ask), and honest about the one
/// that doesn't do anything yet rather than omitting it and leaving the
/// GM to wonder. Kept in sync by hand with whatever's actually wired in
/// `coach_stats.dart`'s 5 fields -- update this alongside any future
/// change to what a stat affects, the same way `coaching-stats-notes.md`
/// (the fuller internal design-notes version of this same information)
/// needs updating too.
class _CoachingSection extends StatelessWidget {
  const _CoachingSection();

  static const _stats = [
    (
      label: 'Offense',
      description:
          'Boosts your team during a game when your Offense beats the '
          'other coach\'s Defense.',
    ),
    (
      label: 'Defense',
      description:
          'The same matchup in reverse -- a strong Defense coach blunts '
          'the other team\'s offense.',
    ),
    (
      label: 'Development',
      description: 'How fast your players grow in training, week to week.',
    ),
    (
      label: 'Motivation',
      description:
          'Powers your quarter-break coaching calls up or down -- 50 is '
          'standard, higher amplifies a call like Focus Defense, lower '
          'dampens it.',
    ),
    (
      label: 'Management',
      description:
          'Doesn\'t affect anything yet -- reserved for a future trade '
          'and draft system.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coaching', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final stat in _stats) ...[
            Text(
              stat.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(stat.description, style: theme.textTheme.bodySmall),
            if (stat != _stats.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
