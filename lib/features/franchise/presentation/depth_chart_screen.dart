import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../player/domain/archetype.dart';
import '../../player/domain/player.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/domain/target_minutes.dart';
import '../application/current_franchise_provider.dart';
import '../domain/franchise.dart';

/// Rank the active roster by target minutes -- a full 12-player
/// minutes-ranked ordering beyond the 5-slot starting lineup. List position
/// *is* the rank; [targetMinutesForRank] is shown next to each row as an
/// informational note only -- nothing consumes these minutes yet (that's
/// Phase 3's automatic-substitution engine), this just lets the GM set the
/// order ahead of time.
class DepthChartScreen extends ConsumerStatefulWidget {
  const DepthChartScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  ConsumerState<DepthChartScreen> createState() => _DepthChartScreenState();
}

class _DepthChartScreenState extends ConsumerState<DepthChartScreen> {
  late List<RosterMembership> _active;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _active = widget.franchise.roster
        .where((membership) => membership.status == RosterStatus.active)
        .toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final membership = _active.removeAt(oldIndex);
      _active.insert(newIndex, membership);
    });
  }

  /// "Let the Coach set the order" (2026-08-10, a direct GM ask) --
  /// ranks by overall, best first, the simplest real stand-in for "win
  /// now." Doesn't save on its own -- same as a manual drag, the GM
  /// still has to tap Save (or can keep adjusting first).
  void _autoFillByOverall() {
    setState(() {
      _active.sort(
        (a, b) => b.player.ratings.overall.compareTo(a.player.ratings.overall),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Coach set a win-now order by OVR -- developmental minutes are '
          'still your call.',
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final reorderedIds = _active.map((m) => m.player.id).toList();
    final newRoster = [
      for (final id in reorderedIds)
        widget.franchise.roster.firstWhere((m) => m.player.id == id),
      for (final membership in widget.franchise.roster)
        if (membership.status != RosterStatus.active) membership,
    ];
    await ref
        .read(currentFranchiseProvider.notifier)
        .updateRosterOrder(newRoster);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final developmental = widget.franchise.roster
        .where((m) => m.status == RosterStatus.developmental)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bench Order')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Drag to set your minutes-ranked order -- the top 5 are '
                'your starters.',
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _autoFillByOverall,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Let the Coach Set the Order'),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ReorderableListView(
                  // onReorderItem isn't available yet on this SDK (3.44.4).
                  // ignore: deprecated_member_use
                  onReorder: _onReorder,
                  children: [
                    for (var i = 0; i < _active.length; i++)
                      _DepthChartRow(
                        key: ValueKey(_active[i].player.id),
                        rank: i + 1,
                        membership: _active[i],
                        franchise: widget.franchise,
                      ),
                  ],
                ),
              ),
              if (developmental.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Developmental (0 min)',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      for (final membership in developmental) ...[
                        Text(_rowLabel(membership.player)),
                        if (membership != developmental.last)
                          const Divider(height: AppSpacing.lg),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('Save Bench Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepthChartRow extends StatelessWidget {
  const _DepthChartRow({
    required this.rank,
    required this.membership,
    required this.franchise,
    required Key key,
  }) : super(key: key);

  final int rank;
  final RosterMembership membership;
  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = membership.player;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: AppCard(
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PortraitImage(
              saveId: franchise.id,
              ownerId: player.id,
              appearance: player.appearance,
              jersey: parseHexColor(franchise.team.colors.primaryHex),
              size: 36,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(_rowLabel(player), style: theme.textTheme.bodyLarge),
            ),
            Text(
              '${targetMinutesForRank(rank)} min',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// "C #16 Tran (Point Forward, 85 OVR)" -- position, jersey number (when
/// assigned), surname, archetype, and overall in one compact line. Shared
/// between the ranked active-roster rows and the developmental list above
/// them so both read the same way.
String _rowLabel(Player player) {
  final jersey = player.jerseyNumber != null ? '#${player.jerseyNumber} ' : '';
  return '${player.primaryPosition.abbreviation} $jersey${player.lastName} '
      '(${player.archetype.label}, ${player.ratings.overall} OVR)';
}
