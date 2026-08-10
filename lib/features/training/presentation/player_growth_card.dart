import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/player_rating_field.dart';
import '../domain/training_report.dart';

/// The raw sum of a result's field-level deltas -- what actually got
/// applied, unlike [PlayerGrowthResult.overallDelta] (a rounded 12-field
/// average that can read as 0 even when real fields moved). Shared by
/// every screen that lists [PlayerGrowthResult]s: used to both sort
/// (growth first, decline last) and headline each [PlayerGrowthCard].
int totalPlayerGrowthDelta(PlayerGrowthResult result) =>
    result.fieldDeltas.values.fold(0, (a, b) => a + b);

/// One player's growth/decline card -- name, a headline total (icon +
/// explicit sign, not color alone, per `ARCHITECTURE.md`'s accessibility
/// rule), and a row of per-field delta chips underneath. Originally
/// `TrainingReportScreen`-only (one week's results); promoted out to a
/// shared widget (2026-08-10) once `SeasonRecapScreen`'s player-
/// development section needed the exact same look for a whole season's
/// aggregated totals (`aggregateSeasonGrowth`) -- [PlayerGrowthResult]
/// itself doesn't distinguish "one week" from "many summed together," so
/// neither does this card.
class PlayerGrowthCard extends StatelessWidget {
  const PlayerGrowthCard({
    required this.playerName,
    required this.result,
    super.key,
  });

  final String playerName;
  final PlayerGrowthResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalPlayerGrowthDelta(result);
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
