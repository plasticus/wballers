import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/onboarding/onboarding_screen.dart';
import '../../training/domain/training_report.dart';
import '../../training/presentation/training_report_screen.dart';

/// A reverse-chronological feed of what's happened around the franchise --
/// the browsable archive `0B_Planned.md` calls "the News feed", previously
/// just a name on a list. Training reports (`Franchise.trainingReports`)
/// are the only real news source that exists today; every other surfaced
/// moment this game will eventually produce (a nickname earned, an award
/// won, a big trade) is future work, but this screen is built to grow into
/// that rather than get rebuilt for it -- see [_NewsItem], the one place a
/// new source would plug in.
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchiseState = ref.watch(currentFranchiseProvider);

    return switch (franchiseState) {
      AsyncData(:final value?) => _NewsFeed(franchise: value),
      AsyncData() => const _NoFranchiseView(),
      AsyncError() => const ErrorStateView(
        message: 'Could not load your franchise save.',
      ),
      _ => const LoadingView(message: 'Loading your news…'),
    };
  }
}

class _NoFranchiseView extends StatelessWidget {
  const _NoFranchiseView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.newspaper_outlined,
      message: 'Create an expansion franchise to start generating news.',
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

/// One thing worth telling the GM about. Currently only ever wraps a
/// [TrainingReport] -- deliberately not a bigger sealed hierarchy yet,
/// since there's nothing else real to put in one; the next news source
/// (an award, a nickname) should add its own variant here rather than a
/// parallel screen.
class _NewsItem {
  const _NewsItem.trainingReport(this.trainingReport);

  final TrainingReport trainingReport;

  int get week => trainingReport.week;
}

class _NewsFeed extends StatelessWidget {
  const _NewsFeed({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final report in franchise.trainingReports)
        _NewsItem.trainingReport(report),
    ]..sort((a, b) => b.week.compareTo(a.week));

    if (items.isEmpty) {
      return const EmptyStateView(
        icon: Icons.newspaper_outlined,
        message:
            'No news yet -- check back once your team starts training '
            'and playing games.',
      );
    }

    return ListView(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _NewsItemCard(franchise: franchise, item: items[i]),
          if (i != items.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _NewsItemCard extends StatelessWidget {
  const _NewsItemCard({required this.franchise, required this.item});

  final Franchise franchise;
  final _NewsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = item.trainingReport;
    final changedCount = report.results.length;

    return AppCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  TrainingReportScreen(franchise: franchise, report: report),
            ),
          );
        },
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${report.week} Training Report',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    changedCount == 0
                        ? 'No one moved the needle this week.'
                        : '$changedCount player${changedCount == 1 ? '' : 's'} '
                              'changed.',
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
