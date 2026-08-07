import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../mail/domain/mail_item.dart';
import '../../player/domain/player.dart';
import '../../player/domain/position.dart';
import '../domain/player_rating_field.dart';
import '../domain/training_report.dart';

/// The result of one weekly training cycle, shown right after it resolves
/// -- per-player field-level changes and all. Same "transient surfaced
/// moment" deal as `GameResultScreen`: [Franchise.trainingReports] keeps
/// the lean [TrainingReport] history around (results only, no re-render
/// of this screen's sorted/labeled presentation), so this is the richest
/// view of a given week's training a GM ever sees.
///
/// Marks its own Mail inbox item read on open (`markMailRead`,
/// `trainingReportMailId`) -- every entry point (the Dashboard's
/// "Training Report Ready" card, its Recent card, and the Mail tab's own
/// list) funnels through here, so this is the one place that needs to
/// know about read state at all.
class TrainingReportScreen extends ConsumerStatefulWidget {
  const TrainingReportScreen({
    required this.franchise,
    required this.report,
    super.key,
  });

  final Franchise franchise;
  final TrainingReport report;

  @override
  ConsumerState<TrainingReportScreen> createState() =>
      _TrainingReportScreenState();
}

class _TrainingReportScreenState extends ConsumerState<TrainingReportScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred a frame -- calling this synchronously in initState would
    // modify the provider while the widget tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(currentFranchiseProvider.notifier)
          .markMailRead(trainingReportMailId(widget.report.week));
    });
  }

  String _playerLabel(String playerId) {
    for (final membership in widget.franchise.roster) {
      if (membership.player.id == playerId) {
        final player = membership.player;
        final jersey = player.jerseyNumber != null
            ? '#${player.jerseyNumber} '
            : '';
        return '${player.primaryPosition.abbreviation} $jersey${player.name}';
      }
    }
    // Shouldn't happen -- every result comes from this franchise's own
    // roster at the moment training resolved -- but a label beats a crash
    // if a player was somehow since removed from the save.
    return 'Former Player';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = widget.report;
    final sortedResults = [...report.results]
      ..sort((a, b) => _totalDelta(b).compareTo(_totalDelta(a)));

    return Scaffold(
      appBar: AppBar(title: const Text('Training Report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Week ${report.week}', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              sortedResults.isEmpty
                  ? 'No one moved the needle this week.'
                  : '${sortedResults.length} player'
                        '${sortedResults.length == 1 ? '' : 's'} changed.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < sortedResults.length; i++) ...[
              _PlayerGrowthCard(
                playerName: _playerLabel(sortedResults[i].playerId),
                result: sortedResults[i],
              ),
              if (i != sortedResults.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// The raw sum of a result's field-level deltas -- what actually got
/// applied, unlike [PlayerGrowthResult.overallDelta] (a rounded 12-field
/// average that can read as 0 even when real fields moved). Used to both
/// sort (growth first, decline last) and headline each card.
int _totalDelta(PlayerGrowthResult result) =>
    result.fieldDeltas.values.fold(0, (a, b) => a + b);

class _PlayerGrowthCard extends StatelessWidget {
  const _PlayerGrowthCard({required this.playerName, required this.result});

  final String playerName;
  final PlayerGrowthResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalDelta(result);
    final isGrowth = total >= 0;
    final color = isGrowth ? Colors.green.shade700 : Colors.red.shade700;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(playerName, style: theme.textTheme.titleMedium),
              ),
              // Icon + explicit sign, not color alone (accessibility rule
              // in ARCHITECTURE.md).
              Icon(
                isGrowth ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${total >= 0 ? '+' : ''}$total',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final entry in result.fieldDeltas.entries)
                _FieldDeltaChip(field: entry.key, delta: entry.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldDeltaChip extends StatelessWidget {
  const _FieldDeltaChip({required this.field, required this.delta});

  final PlayerRatingField field;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGrowth = delta >= 0;
    final color = isGrowth ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${field.label} ${delta >= 0 ? '+' : ''}$delta',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
