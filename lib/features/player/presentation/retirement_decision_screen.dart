import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/domain/pending_retirement.dart';
import '../../mail/domain/mail_item.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../domain/player.dart';
import '../domain/retirement_reason.dart';
import 'player_card_widgets.dart';

/// The GM's real decision point for a [PendingRetirement]
/// (2026-08-11, `0D_Season_2_Roadmap.md`'s Aging & roster churn stage --
/// "the coach can attempt to convince them to play for one more year, a
/// skill check"): let the player retire, or have the coach attempt to
/// talk them into one more season
/// (`current_franchise_provider.dart`'s `resolvePendingRetirement`).
/// Reached from [RetirementDecisionMailItem] in the Mail tab.
class RetirementDecisionScreen extends ConsumerStatefulWidget {
  const RetirementDecisionScreen({
    required this.franchise,
    required this.item,
    super.key,
  });

  final Franchise franchise;
  final RetirementDecisionMailItem item;

  @override
  ConsumerState<RetirementDecisionScreen> createState() =>
      _RetirementDecisionScreenState();
}

class _RetirementDecisionScreenState
    extends ConsumerState<RetirementDecisionScreen> {
  var _isResolving = false;

  Future<void> _resolve({required bool attemptPersuasion}) async {
    setState(() => _isResolving = true);
    final outcome = await ref
        .read(currentFranchiseProvider.notifier)
        .resolvePendingRetirement(
          widget.item.pending.playerId,
          attemptPersuasion: attemptPersuasion,
        );
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final playerName = widget.item.player.name;
    final message = switch (outcome) {
      RetirementDecisionOutcome.letRetire =>
        '$playerName retires. Thanks for everything.',
      RetirementDecisionOutcome.persuadedToStay =>
        'Your coach talked $playerName into playing one more season.',
      RetirementDecisionOutcome.persuasionFailed =>
        'Your coach couldn\'t change $playerName\'s mind -- she retires.',
      null => 'That decision was already resolved.',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRetire(BuildContext context) async {
    final player = widget.item.player;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Let her retire?'),
        content: Text(
          '${player.name} will leave the league for good -- this can\'t '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Let Her Retire'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _resolve(attemptPersuasion: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = widget.item.player;
    final reason = widget.item.pending.reason;
    final accentColor = widget.franchise.team.colors.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Retirement Decision')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Row(
                children: [
                  PhotoWithJerseyBadge(
                    franchise: widget.franchise,
                    player: player,
                    accentColor: accentColor,
                    jersey: parseHexColor(
                      widget.franchise.team.colors.primaryHex,
                    ),
                    size: 72,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.name, style: theme.textTheme.titleLarge),
                        Text(
                          '${player.primaryPosition.label} · Age '
                          '${player.age} · ${player.ratings.overall} OVR',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(reason.label, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your coach can attempt to convince her to play one more '
              'season -- how persuasive that attempt is depends on the '
              'coach\'s Motivation. Or you can let her go with the '
              'league\'s thanks.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _isResolving
                  ? null
                  : () => _resolve(attemptPersuasion: true),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Try to Convince Her to Stay'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _isResolving ? null : () => _confirmRetire(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Let Her Retire'),
            ),
          ],
        ),
      ),
    );
  }
}
