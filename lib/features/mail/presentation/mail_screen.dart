import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/onboarding/onboarding_screen.dart';
import '../../market/presentation/player_market_screen.dart';
import '../../player/domain/retirement_reason.dart';
import '../../player/presentation/retirement_decision_screen.dart';
import '../../season/presentation/all_star_game_result_screen.dart';
import '../../season/presentation/skills_competition_result_screen.dart';
import '../../training/presentation/training_report_screen.dart';
import '../application/mailbox.dart';
import '../domain/mail_item.dart';

/// The GM's inbox -- replaces the old, purely-passive `NewsScreen` (a
/// direct GM ask: "drop the News button off the home screen, should be
/// replaced with a Mail button"). Lists everything [mailboxFor] derives
/// for the current franchise: proactive [AssistantGmMailItem]s first,
/// then every [TrainingReportMailItem] newest week first -- the same
/// feed the old News tab showed, just no longer the only thing living
/// here.
class MailScreen extends ConsumerWidget {
  const MailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchiseState = ref.watch(currentFranchiseProvider);

    return switch (franchiseState) {
      AsyncData(:final value?) => _MailInbox(franchise: value),
      AsyncData() => const _NoFranchiseView(),
      AsyncError() => const ErrorStateView(
        message: 'Could not load your franchise save.',
      ),
      _ => const LoadingView(message: 'Loading your mail…'),
    };
  }
}

class _NoFranchiseView extends StatelessWidget {
  const _NoFranchiseView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.mail_outline,
      message: 'Create an expansion franchise to start receiving mail.',
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
}

class _MailInbox extends ConsumerWidget {
  const _MailInbox({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = mailboxFor(franchise);

    if (items.isEmpty) {
      return const EmptyStateView(
        icon: Icons.mail_outline,
        message:
            'No mail yet -- check back once your team starts training '
            'and playing games.',
      );
    }

    return ListView(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _MailRow(franchise: franchise, item: items[i]),
          if (i != items.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MailRow extends ConsumerWidget {
  const _MailRow({required this.franchise, required this.item});

  final Franchise franchise;
  final MailItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = !franchise.readMailIds.contains(item.id);
    final item0 = item;

    final (from, icon, preview) = switch (item0) {
      AssistantGmMailItem() => ('Assistant GM', Icons.mail_outline, item0.body),
      TrainingReportMailItem() => (
        'Training Staff',
        Icons.fitness_center_outlined,
        item0.report.results.isEmpty
            ? 'No one moved the needle this week.'
            : '${item0.report.results.length} player'
                  '${item0.report.results.length == 1 ? '' : 's'} changed.',
      ),
      SkillsCompetitionMailItem() => (
        'League Office',
        Icons.stars_outlined,
        'Results are in for the 3-Point Shootout, H-O-R-S-E, and the '
            'Defensive Skills Challenge.',
      ),
      AllStarGameMailItem() => (
        'League Office',
        Icons.emoji_events_outlined,
        'Final: ${item0.playedGame.homeScore}-${item0.playedGame.awayScore}.',
      ),
      RetirementDecisionMailItem() => (
        'Coaching Staff',
        Icons.watch_later_outlined,
        item0.pending.reason.label,
      ),
    };

    return AppCard(
      child: InkWell(
        onTap: () async {
          await ref
              .read(currentFranchiseProvider.notifier)
              .markMailRead(item0.id);
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => switch (item0) {
                AssistantGmMailItem() => _AssistantGmMailDetailScreen(
                  franchise: franchise,
                  item: item0,
                ),
                TrainingReportMailItem() => TrainingReportScreen(
                  franchise: franchise,
                  report: item0.report,
                ),
                SkillsCompetitionMailItem() => SkillsCompetitionResultScreen(
                  franchise: franchise,
                  result: item0.result,
                ),
                AllStarGameMailItem() => AllStarGameResultScreen(
                  franchise: franchise,
                  playedGame: item0.playedGame,
                  squads: item0.squads,
                ),
                RetirementDecisionMailItem() => RetirementDecisionScreen(
                  franchise: franchise,
                  item: item0,
                ),
              },
            ),
          );
        },
        child: Row(
          children: [
            // A filled dot, not color alone, marks unread -- the same
            // "never rely on color alone" rule every other status
            // indicator in this app follows.
            if (isUnread) ...[
              Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
            ] else
              const SizedBox(width: 8 + AppSpacing.xs),
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item0.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'From $from',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// An [AssistantGmMailItem] opened full-screen, styled like a real email
/// (To/From/Subject header block, then the message body) -- a direct GM
/// ask: "That note should show up in Mail, and look kind of like an
/// email, you know?"
class _AssistantGmMailDetailScreen extends StatelessWidget {
  const _AssistantGmMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final AssistantGmMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    _MailHeaderRow(label: 'From', value: 'Assistant GM'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(item.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerMarketScreen(franchise: franchise),
                    ),
                  );
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Open Player Market'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MailHeaderRow extends StatelessWidget {
  const _MailHeaderRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
