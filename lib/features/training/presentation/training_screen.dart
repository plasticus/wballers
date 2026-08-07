import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_status.dart';
import '../domain/player_rating_field.dart';
import '../domain/training_coach.dart';
import '../domain/training_focus.dart';
import '../domain/training_plan.dart';

/// The GM's training instructions: a team-wide default direction, plus
/// up to 3 individual training coaches who can each point a different
/// direction (broad or one specific rating) than the team plan
/// (`0B_Planned.md`'s decided training design). Settings are sticky --
/// nothing here resolves anything by itself; [runTrainingAndPersist]
/// (`current_franchise_provider.dart`) is what actually applies whatever
/// this screen last saved, once a week's worth of games completes.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  late TrainingFocus _teamFocus;
  late List<_CoachAssignment> _assignments;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.franchise.trainingPlan;
    _teamFocus = plan.teamFocus;
    _assignments = [
      for (final slot in plan.coachSlots) _CoachAssignment.fromSlot(slot),
    ];
  }

  /// The roster players eligible to be assigned to a coach at all --
  /// mirrors [runTraining]'s own skip of `RosterStatus.reserveInactive`,
  /// so the picker never offers an assignment that would silently do
  /// nothing. Carries enough to render "PG #49 Kayla Silva (67 OVR, 99
  /// POT)" in the picker -- a bare name gave the GM no way to tell a
  /// promising 21-year-old from a declining vet without leaving this
  /// screen, which mattered most exactly where it's used: putting high-
  /// potential players in these 3 individually-coached slots is the whole
  /// point.
  List<({String id, String label})> get _eligiblePlayers => [
    for (final membership in widget.franchise.roster)
      if (membership.status != RosterStatus.reserveInactive)
        (id: membership.player.id, label: _playerLabel(membership.player)),
  ];

  String _playerName(String id) {
    final membership = widget.franchise.roster.firstWhere(
      (m) => m.player.id == id,
    );
    return membership.player.name;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final newPlan = TrainingPlan(
      teamFocus: _teamFocus,
      coachSlots: [for (final assignment in _assignments) assignment.toSlot()],
    );
    await ref
        .read(currentFranchiseProvider.notifier)
        .updateTrainingPlan(newPlan);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaches = widget.franchise.trainingCoaches;

    return Scaffold(
      appBar: AppBar(title: const Text('Training')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Team Focus', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'What every player without an individually-assigned coach '
                'trains toward. Sticks until you change it.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<TrainingFocus>(
                segments: [
                  for (final focus in TrainingFocus.values)
                    ButtonSegment(value: focus, label: Text(focus.label)),
                ],
                selected: {_teamFocus},
                onSelectionChanged: (selection) =>
                    setState(() => _teamFocus = selection.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Training Coaches', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Point one coach at a player to override the team focus '
                'just for them -- a broad direction or one specific rating '
                'to hyper-focus. One-on-one attention grows a player '
                'faster than the team-wide plan does, so a high-potential '
                'prospect gets the most out of one of these 3 slots.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < coaches.length; i++) ...[
                _CoachAssignmentCard(
                  coach: coaches[i],
                  assignment: _assignments[i],
                  eligiblePlayers: _eligiblePlayers,
                  assignedElsewhereNames: {
                    for (var j = 0; j < _assignments.length; j++)
                      if (j != i && _assignments[j].playerId != null)
                        _assignments[j].playerId!: _playerName(
                          _assignments[j].playerId!,
                        ),
                  }.keys.toSet(),
                  onChanged: (updated) =>
                      setState(() => _assignments[i] = updated),
                ),
                if (i != coaches.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Training Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One coach slot's in-progress edit state -- richer than
/// [TrainingCoachSlot] itself, since [broadFocus]/[specificField] are
/// both kept around even while idle so toggling between broad/specific
/// (or unassigning and reassigning) doesn't discard whatever the GM had
/// picked before.
class _CoachAssignment {
  _CoachAssignment({
    required this.playerId,
    required this.isSpecific,
    required this.broadFocus,
    required this.specificField,
  });

  factory _CoachAssignment.fromSlot(TrainingCoachSlot slot) {
    final focus = slot.focus;
    return _CoachAssignment(
      playerId: slot.playerId,
      isSpecific: focus?.isSpecific ?? false,
      broadFocus: focus?.broadFocus ?? TrainingFocus.balanced,
      specificField: focus?.specificRating ?? PlayerRatingField.speed,
    );
  }

  final String? playerId;
  final bool isSpecific;
  final TrainingFocus broadFocus;
  final PlayerRatingField specificField;

  bool get isAssigned => playerId != null;

  _CoachAssignment copyWith({
    String? Function()? playerId,
    bool? isSpecific,
    TrainingFocus? broadFocus,
    PlayerRatingField? specificField,
  }) {
    return _CoachAssignment(
      playerId: playerId != null ? playerId() : this.playerId,
      isSpecific: isSpecific ?? this.isSpecific,
      broadFocus: broadFocus ?? this.broadFocus,
      specificField: specificField ?? this.specificField,
    );
  }

  /// Converts back to the real domain shape -- an idle assignment (no
  /// player) always saves as a fully-null [TrainingCoachSlot], regardless
  /// of whatever broad/specific choice was staged for it.
  TrainingCoachSlot toSlot() {
    if (playerId == null) return const TrainingCoachSlot();
    return TrainingCoachSlot(
      playerId: playerId,
      focus: isSpecific
          ? IndividualTrainingFocus.specific(specificField)
          : IndividualTrainingFocus.broad(broadFocus),
    );
  }
}

class _CoachAssignmentCard extends StatelessWidget {
  const _CoachAssignmentCard({
    required this.coach,
    required this.assignment,
    required this.eligiblePlayers,
    required this.assignedElsewhereNames,
    required this.onChanged,
  });

  final TrainingCoach coach;
  final _CoachAssignment assignment;
  final List<({String id, String label})> eligiblePlayers;

  /// Player ids already claimed by one of the *other* two coach slots --
  /// excluded from this card's player picker so the GM can't double-assign
  /// the same player to two coaches at once.
  final Set<String> assignedElsewhereNames;

  final ValueChanged<_CoachAssignment> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectable = [
      for (final player in eligiblePlayers)
        if (player.id == assignment.playerId ||
            !assignedElsewhereNames.contains(player.id))
          player,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(coach.name, style: theme.textTheme.titleMedium),
              ),
              Text(
                'DEV ${coach.developmentRating}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: assignment.playerId,
            // Without this, a long player label sizes the closed
            // dropdown's own Row to its intrinsic (unbounded) width
            // instead of the field's actual width, overflowing next to
            // the dropdown arrow -- `overflow`/`maxLines` on the Text
            // itself can't help since that Row never constrains it in
            // the first place.
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Assigned player',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              for (final player in selectable)
                DropdownMenuItem(
                  value: player.id,
                  child: Text(
                    player.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
            onChanged: (playerId) =>
                onChanged(assignment.copyWith(playerId: () => playerId)),
          ),
          if (assignment.isAssigned) ...[
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Broad')),
                ButtonSegment(value: true, label: Text('Specific')),
              ],
              selected: {assignment.isSpecific},
              onSelectionChanged: (selection) =>
                  onChanged(assignment.copyWith(isSpecific: selection.first)),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (assignment.isSpecific)
              DropdownButtonFormField<PlayerRatingField>(
                initialValue: assignment.specificField,
                decoration: const InputDecoration(
                  labelText: 'Rating to hyper-focus',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final field in PlayerRatingField.values)
                    DropdownMenuItem(value: field, child: Text(field.label)),
                ],
                onChanged: (field) {
                  if (field != null) {
                    onChanged(assignment.copyWith(specificField: field));
                  }
                },
              )
            else
              SegmentedButton<TrainingFocus>(
                segments: [
                  for (final focus in TrainingFocus.values)
                    ButtonSegment(value: focus, label: Text(focus.label)),
                ],
                selected: {assignment.broadFocus},
                onSelectionChanged: (selection) =>
                    onChanged(assignment.copyWith(broadFocus: selection.first)),
              ),
          ],
        ],
      ),
    );
  }
}

/// "PG #49 Kayla Silva (67 OVR, 99 POT)" -- position, jersey number (when
/// assigned), full name, overall, and potential, so the individual-coach
/// picker doubles as a quick scan for "who's worth putting in one of these
/// 3 slots" without leaving this screen.
String _playerLabel(Player player) {
  final jersey = player.jerseyNumber != null ? '#${player.jerseyNumber} ' : '';
  return '${player.primaryPosition.abbreviation} $jersey${player.name} '
      '(${player.ratings.overall} OVR, ${player.ratings.potential} POT)';
}
