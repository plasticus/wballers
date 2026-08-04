import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/lineup_legality.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../../roster/domain/starting_lineup.dart';
import '../application/current_franchise_provider.dart';
import '../domain/franchise.dart';

/// Edit the starting five, one player per position. A combo player (one
/// with a matching secondary position) can appear as an option for more
/// than one slot; picking the same player for two slots is caught by
/// [evaluateLineupLegality] and blocks Save rather than being prevented by
/// the dropdowns themselves -- simpler than making every dropdown reactive
/// to every other dropdown's current pick.
class LineupEditorScreen extends ConsumerStatefulWidget {
  const LineupEditorScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  ConsumerState<LineupEditorScreen> createState() => _LineupEditorScreenState();
}

class _LineupEditorScreenState extends ConsumerState<LineupEditorScreen> {
  late Map<Position, String> _draft;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _draft = Map.of(widget.franchise.startingLineup.startersByPosition);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref
        .read(currentFranchiseProvider.notifier)
        .updateLineup(StartingLineup(startersByPosition: _draft));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roster = widget.franchise.roster;
    final legality = evaluateLineupLegality(
      StartingLineup(startersByPosition: _draft),
      roster,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Starting Lineup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final position in Position.values) ...[
                      _PositionPicker(
                        position: position,
                        roster: roster,
                        selectedPlayerId: _draft[position],
                        onChanged: (playerId) {
                          if (playerId == null) return;
                          setState(() => _draft[position] = playerId);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
              if (!legality.isLegal) ...[
                Text(
                  _legalityMessage(legality),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton(
                onPressed: legality.isLegal && !_isSaving ? _save : null,
                child: const Text('Save Lineup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _legalityMessage(LineupLegality legality) {
  if (!legality.hasAllPositionsFilled) {
    return 'Every position needs a starter.';
  }
  if (!legality.hasNoDuplicatePlayers) {
    return 'Each starter can only fill one position.';
  }
  return 'Every starter must be on the active roster and eligible for their position.';
}

class _PositionPicker extends StatelessWidget {
  const _PositionPicker({
    required this.position,
    required this.roster,
    required this.selectedPlayerId,
    required this.onChanged,
  });

  final Position position;
  final List<RosterMembership> roster;
  final String? selectedPlayerId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligible =
        roster
            .where(
              (m) =>
                  m.status == RosterStatus.active &&
                  StartingLineup.isEligible(m.player, position),
            )
            .toList()
          ..sort(
            (a, b) =>
                b.player.ratings.overall.compareTo(a.player.ratings.overall),
          );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_positionLabel(position), style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (eligible.isEmpty)
            const Text('No eligible players on the active roster.')
          else
            DropdownButtonFormField<String>(
              initialValue: selectedPlayerId,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final membership in eligible)
                  DropdownMenuItem(
                    value: membership.player.id,
                    child: Text(
                      '${membership.player.name} (${membership.player.ratings.overall} OVR)',
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

String _positionLabel(Position position) {
  return switch (position) {
    Position.pointGuard => 'Point Guard',
    Position.shootingGuard => 'Shooting Guard',
    Position.smallForward => 'Small Forward',
    Position.powerForward => 'Power Forward',
    Position.center => 'Center',
  };
}
