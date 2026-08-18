import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/player.dart';
import '../../player/presentation/player_card_widgets.dart';
import '../../roster/domain/roster_status.dart';
import '../domain/player_rating_field.dart';
import '../domain/training_coach.dart';
import '../domain/training_focus.dart';
import '../domain/training_plan.dart';
import 'season_to_date_report_screen.dart';

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
  /// nothing. Carries the real [Player], not just a formatted label --
  /// `_CoachAssignmentCard`'s picker renders OVR/POT/AGE as colored chips
  /// (Coach Picker Lab's #3 "Stat Chips", the GM's pick) rather than a
  /// plain text line, so it needs the raw numbers, not a pre-built
  /// string.
  List<({String id, Player player})> get _eligiblePlayers => [
    for (final membership in widget.franchise.roster)
      if (membership.status != RosterStatus.reserveInactive)
        (id: membership.player.id, player: membership.player),
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
              _SeasonToDateReportCard(franchise: widget.franchise),
              const SizedBox(height: AppSpacing.xl),
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
                  displayName: 'Individual Coach #${i + 1}',
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
              const SizedBox(height: AppSpacing.xl),
              const _HowTrainingWorksCard(),
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
    required this.displayName,
    required this.coach,
    required this.assignment,
    required this.eligiblePlayers,
    required this.assignedElsewhereNames,
    required this.onChanged,
  });

  /// "Individual Coach #1"/"#2"/"#3" -- the generated [coach]'s own name
  /// isn't shown (2026-08-07, a direct GM ask: "the three training coaches
  /// don't need names"). [coach] is still the real, distinct generated
  /// coach underneath -- this only changes what's displayed.
  final String displayName;

  final TrainingCoach coach;
  final _CoachAssignment assignment;
  final List<({String id, Player player})> eligiblePlayers;

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

    // Not AppCard -- its generous EdgeInsets.all(AppSpacing.lg) was eating
    // into the one thing on this card that actually needs the room: the
    // player-picker dropdown (2026-08-10, a direct GM ask -- "no reason
    // not to use 100% of the horizontal space for this menu"). Tighter
    // horizontal padding here reclaims real width for it without touching
    // the rest of the screen's layout.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No development-rating readout here (2026-08-10, a direct GM
            // ask: "that's engine stuff the player doesn't need to see")
            // -- this coach carries no rating of its own to show at all
            // (`TrainingCoach`'s own doc comment on why).
            Text(displayName, style: theme.textTheme.titleMedium),
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
              // "Stat Chips" (Coach Picker Lab #3, `coach_picker_lab_screen
              // .dart`) landed for real 2026-08-11 -- the GM's favorite of
              // the 5 comparisons, plus 2 direct asks on top: an AGE chip
              // alongside OVR/POT, and the collapsed/selected field
              // showing all 3 as bare numbers rather than just one
              // OVR-only pill.
              selectedItemBuilder: (context) => [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Unassigned'),
                ),
                for (final player in selectable)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _CoachPickerSelectedItem(player: player.player),
                  ),
              ],
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                for (final player in selectable)
                  DropdownMenuItem(
                    value: player.id,
                    child: _CoachPickerMenuItem(player: player.player),
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
                  onSelectionChanged: (selection) => onChanged(
                    assignment.copyWith(broadFocus: selection.first),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The open dropdown-menu-item row for one player: `${position} ${jersey}
/// ${lastName}` followed by labelled OVR/POT/AGE chips (`StatChip`,
/// `player_card_widgets.dart`) -- Coach Picker Lab #3, plus the AGE chip
/// the GM added on top of the lab version.
class _CoachPickerMenuItem extends StatelessWidget {
  const _CoachPickerMenuItem({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jersey = player.jerseyNumber != null
        ? '#${player.jerseyNumber} '
        : '';
    final lastName = player.name.split(' ').skip(1).join(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '${player.primaryPosition.abbreviation} $jersey$lastName',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatChip(
          label: 'OVR',
          value: player.ratings.overall,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        StatChip(
          label: 'POT',
          value: player.ratings.potential,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        StatChip(
          label: 'AGE',
          value: player.age,
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }
}

/// The closed/collapsed field once a player is selected: last name plus
/// the same 3 chips as bare numbers, no unit labels -- a direct GM ask
/// on top of adopting Coach Picker Lab #3 ("have all three chips just as
/// numbers when a player is selected").
class _CoachPickerSelectedItem extends StatelessWidget {
  const _CoachPickerSelectedItem({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastName = player.name.split(' ').skip(1).join(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(lastName, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: AppSpacing.sm),
        StatChip(
          label: '',
          value: player.ratings.overall,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        StatChip(
          label: '',
          value: player.ratings.potential,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        StatChip(
          label: '',
          value: player.age,
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }
}

/// A quick link to the live, always-current [SeasonToDateReportScreen]
/// (2026-08-10, TODO.md item 5) -- sits at the very top of the Training
/// page since "how's everyone doing so far this season" is something a
/// GM would want to check on the way in, not something buried below the
/// team-focus/coach-assignment controls.
class _SeasonToDateReportCard extends StatelessWidget {
  const _SeasonToDateReportCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Season To Date', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Every roster player\'s growth so far this season, '
                  'most improved first.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SeasonToDateReportScreen(franchise: franchise),
                ),
              );
            },
            child: const Text('View Report'),
          ),
        ],
      ),
    );
  }
}

/// A brief, plain-language summary of how weekly training actually
/// works -- direct GM quote: "I am writing the program, and even I
/// don't know how it works" (2026-08-10, TODO.md item 6). This is
/// deliberately short (a handful of sentences, no numbers); the full
/// breakdown with 3 worked examples lives in a separate detailed
/// reference doc, matching this project's established HTML-artifact
/// convention for design/reference docs -- this card just gets the GM
/// oriented without leaving the screen.
class _HowTrainingWorksCard extends StatelessWidget {
  const _HowTrainingWorksCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How Training Works', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Every week, active and developmental players inch toward '
            'their potential -- the bigger the gap between where they '
            'are now and their ceiling, the faster they grow, especially '
            'with real minutes on the floor. A bench player who barely '
            'plays barely develops, no matter how high their potential '
            'is.\n\n'
            'Past their prime (around 30 and up), players decline a '
            'little each week too, with the rest of a veteran\'s yearly '
            'decline landing in one lump at the end of the season.\n\n'
            'Team Focus decides which ratings move for everyone by '
            'default. Give a player to one of your 3 individual coaches '
            'to override that just for them -- a broad direction, or one '
            'specific rating to really hyper-focus.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
