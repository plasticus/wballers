import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../application/season_recap_history_provider.dart';
import 'season_recap_screen.dart';

/// Every season this save has ever completed, most recent first, each
/// one still reachable for the life of the save (2026-08-22, a direct
/// GM ask: "I want to keep post season reports forever (well, for the
/// life of the save). They all need to live somewhere.") --
/// [seasonRecapSeasonsProvider]'s own doc comment covers why a single
/// "last completed season" card wasn't enough on its own.
class SeasonRecapHistoryScreen extends ConsumerWidget {
  const SeasonRecapHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(seasonRecapSeasonsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Season Recaps')),
      body: SafeArea(
        child: switch (seasons) {
          AsyncData(:final value) when value.isEmpty => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'No completed seasons yet -- your first recap shows up '
                'here once Season 1 wraps.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          AsyncData(:final value) => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: value.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SeasonRecapRow(season: value[index]),
            ),
          ),
          AsyncError() => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: Text('Could not load your season recaps.')),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// One season's row -- [season]'s own recap loads lazily (only once this
/// row actually renders), so a save with many seasons' worth of history
/// doesn't have to load every one of them just to show the list.
class _SeasonRecapRow extends ConsumerWidget {
  const _SeasonRecapRow({required this.season});

  final int season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref.watch(seasonRecapProvider(season));
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            // Zero-based -- same "+1 for display" convention every
            // other season label in this app already follows.
            child: Text(
              'Season ${season + 1}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          switch (recap) {
            AsyncData(:final value?) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SeasonRecapScreen(franchise: value, readOnly: true),
                  ),
                );
              },
              child: const Text('View'),
            ),
            AsyncData() => Text(
              'Unavailable',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            AsyncError() => Text(
              'Error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            _ => const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          },
        ],
      ),
    );
  }
}
