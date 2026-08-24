import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../mail/domain/mail_item.dart';
import '../../player/domain/player.dart';
import '../../player/domain/position.dart';
import '../domain/training_report.dart';
import 'player_growth_card.dart';

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
    // Waived (`dropPlayer`) since this report resolved -- released, not
    // vanished, so she's still sitting right in `Franchise.freeAgents`
    // with her real name (2026-08-23, a direct GM report -- see
    // `SeasonToDateReportScreen._playerLabel`'s own comment for the
    // full story; kept in sync by hand here too).
    for (final player in widget.franchise.freeAgents) {
      if (player.id == playerId) {
        return '${player.primaryPosition.abbreviation} ${player.name}';
      }
    }
    // A real retirement since this report resolved -- her name still
    // survives in `Franchise.formerPlayers` (a direct GM report,
    // 2026-08-19: a retired all-star showed up here as "Former Player"
    // instead of her own name; see `FormerPlayerRecord`'s own doc
    // comment).
    for (final record in widget.franchise.formerPlayers) {
      if (record.playerId == playerId) return record.label;
    }
    // Shouldn't happen otherwise -- a player traded away to an AI team
    // is the one remaining gap (her name lives on that team's own
    // roster, which this lookup doesn't scan) -- but a label beats a
    // crash if a player was somehow since removed from the save with no
    // trace at all.
    return 'Former Player';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = widget.report;
    final sortedResults = [...report.results]
      ..sort(
        (a, b) =>
            totalPlayerGrowthDelta(b).compareTo(totalPlayerGrowthDelta(a)),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Training Report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(report.weekRangeLabel, style: theme.textTheme.titleLarge),
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
              PlayerGrowthCard(
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
