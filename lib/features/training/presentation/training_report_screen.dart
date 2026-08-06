import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../domain/player_rating_field.dart';
import '../domain/training_report.dart';

/// The result of one weekly training cycle, shown right after it resolves
/// -- per-player field-level changes and all. Same "transient surfaced
/// moment" deal as `GameResultScreen`: [Franchise.trainingReports] keeps
/// the lean [TrainingReport] history around (results only, no re-render
/// of this screen's sorted/labeled presentation), so this is the richest
/// view of a given week's training a GM ever sees.
class TrainingReportScreen extends StatelessWidget {
  const TrainingReportScreen({
    required this.franchise,
    required this.report,
    super.key,
  });

  final Franchise franchise;
  final TrainingReport report;

  String _playerName(String playerId) {
    for (final membership in franchise.roster) {
      if (membership.player.id == playerId) return membership.player.name;
    }
    // Shouldn't happen -- every result comes from this franchise's own
    // roster at the moment training resolved -- but a label beats a crash
    // if a player was somehow since removed from the save.
    return 'Former Player';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                playerName: _playerName(sortedResults[i].playerId),
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
