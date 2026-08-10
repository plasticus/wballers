import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';

/// A stress-test roster for comparing dropdown-item layouts -- deliberately
/// includes 2 long surnames ("Henderson," "Kowalczyk") since the GM's own
/// complaint about the current format was specifically that a long
/// surname pushed POT off-screen entirely. One player has no jersey
/// number at all (a free agent/prospect scenario the real picker also has
/// to handle).
class _LabPlayer {
  const _LabPlayer({
    required this.position,
    this.jersey,
    required this.ovr,
    required this.pot,
    required this.age,
    required this.lastName,
  });

  final String position;
  final int? jersey;
  final int ovr;
  final int pot;
  final int age;
  final String lastName;
}

const _labPlayers = [
  _LabPlayer(
    position: 'C',
    jersey: 42,
    ovr: 68,
    pot: 93,
    age: 21,
    lastName: 'Henderson',
  ),
  _LabPlayer(
    position: 'PF',
    jersey: 13,
    ovr: 61,
    pot: 78,
    age: 24,
    lastName: 'Diallo',
  ),
  _LabPlayer(
    position: 'SG',
    jersey: 7,
    ovr: 74,
    pot: 74,
    age: 29,
    lastName: 'Richardson',
  ),
  _LabPlayer(
    position: 'PG',
    jersey: null,
    ovr: 55,
    pot: 88,
    age: 20,
    lastName: 'Silva',
  ),
  _LabPlayer(
    position: 'SF',
    jersey: 24,
    ovr: 69,
    pot: 69,
    age: 31,
    lastName: 'Kowalczyk',
  ),
];

/// A dev-facing comparison screen: 5 real, working dropdown layouts for
/// `TrainingScreen`'s individual-coaching player picker, side by side --
/// same "build a Lab, don't just guess" precedent `player_card_lab_screen.dart`
/// already established. Direct GM ask (2026-08-10, TODO.md item 5): the
/// current single-line format ("everything in caps like that looks like
/// crap... I maybe just don't know how to fix it") still isn't landing,
/// and the GM has one sketch of a fix (a 2-line dropdown item collapsing
/// to a compact 1-line summary once selected) but wants to see it next to
/// real alternatives before committing to one. Every variation below is a
/// real, functioning `DropdownButtonFormField` -- not a mockup -- built
/// against the same 5-player stress-test roster ([_labPlayers]) so the
/// comparison is apples to apples. Not linked from anywhere a normal
/// playthrough would stumble into by accident (reachable via the Training
/// screen's own "Coach Picker Lab" button, same "not hidden, but not in
/// the way" posture the Card Lab has).
class CoachPickerLabScreen extends StatelessWidget {
  const CoachPickerLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Coach Picker Lab')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Same 5-player roster in every dropdown below -- including 2 '
              'long surnames (Henderson, Kowalczyk), the exact case that '
              'was pushing POT off-screen under the current format. Tap '
              'each one open to see the full list, not just the closed '
              'field.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _LabSection(
              label: '1. Current Format (for reference)',
              child: _CurrentFormatPicker(),
            ),
            const _LabSection(
              label: '2. GM\'s Sketch: 2-Line, Collapses to 1',
              child: _TwoLineCollapsingPicker(),
            ),
            const _LabSection(
              label: '3. Stat Chips',
              child: _StatChipsPicker(),
            ),
            const _LabSection(
              label: '4. Stats-First Hierarchy',
              child: _StatsFirstPicker(),
            ),
            const _LabSection(
              label: '5. Aligned Columns',
              child: _AlignedColumnsPicker(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabSection extends StatelessWidget {
  const _LabSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Shared shell every variation below wraps its dropdown in -- a
/// stateful field so tapping one actually opens/closes/selects for real,
/// not just a static picture of one.
class _PickerScaffold extends StatefulWidget {
  const _PickerScaffold({required this.itemBuilder, this.selectedItemBuilder});

  final Widget Function(BuildContext context, _LabPlayer player) itemBuilder;
  final Widget Function(BuildContext context, _LabPlayer player)?
  selectedItemBuilder;

  @override
  State<_PickerScaffold> createState() => _PickerScaffoldState();
}

class _PickerScaffoldState extends State<_PickerScaffold> {
  int? _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedIndex,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Assigned player',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      selectedItemBuilder: widget.selectedItemBuilder == null
          ? null
          : (context) => [
              for (var i = 0; i < _labPlayers.length; i++)
                Align(
                  alignment: Alignment.centerLeft,
                  child: widget.selectedItemBuilder!(context, _labPlayers[i]),
                ),
            ],
      items: [
        for (var i = 0; i < _labPlayers.length; i++)
          DropdownMenuItem(
            value: i,
            child: widget.itemBuilder(context, _labPlayers[i]),
          ),
      ],
      onChanged: (index) => setState(() => _selectedIndex = index),
    );
  }
}

String _jersey(_LabPlayer p) => p.jersey != null ? '#${p.jersey} ' : '';

/// The production format, unmodified -- "PG #49 67 OVR · 99 POT · 24y ·
/// Richardson," single line, name last since it's what truncates first.
/// Included as the baseline every other variation is measured against.
class _CurrentFormatPicker extends StatelessWidget {
  const _CurrentFormatPicker();

  @override
  Widget build(BuildContext context) {
    return _PickerScaffold(
      itemBuilder: (context, p) => Text(
        '${p.position} ${_jersey(p)}· ${p.ovr} OVR · ${p.pot} POT '
        '· ${p.age}y · ${p.lastName}',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

/// The GM's own sketch, built for real: an open menu item reads two lines
/// ("C #42 · Henderson" bold, "68 OVR, 93 POT, 21y" smaller/muted below),
/// nothing truncates since each line gets its own row -- but the closed
/// field collapses to a single compact line ("C #42 Henderson") via
/// [DropdownButtonFormField.selectedItemBuilder] once something's picked,
/// so the field doesn't grow taller than every other field on the screen
/// just because its own menu items are 2 lines tall.
class _TwoLineCollapsingPicker extends StatelessWidget {
  const _TwoLineCollapsingPicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PickerScaffold(
      itemBuilder: (context, p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${p.position} ${_jersey(p)}· ${p.lastName}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${p.ovr} OVR, ${p.pot} POT, ${p.age}y',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      selectedItemBuilder: (context, p) =>
          Text('${p.position} ${_jersey(p)}${p.lastName}'),
    );
  }
}

/// OVR/POT as small colored pills instead of plain "· 68 OVR ·" text --
/// the GM's "everything in caps like that looks like crap" complaint
/// reads as much about density as literal capitalization; pulling the
/// two numbers that matter most into their own visual chips breaks up
/// the wall of separators-and-caps the current format reads as.
class _StatChipsPicker extends StatelessWidget {
  const _StatChipsPicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PickerScaffold(
      itemBuilder: (context, p) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${p.position} ${_jersey(p)}${p.lastName}',
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatPill(label: '${p.ovr} OVR', color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          _StatPill(label: '${p.pot} POT', color: theme.colorScheme.tertiary),
        ],
      ),
      selectedItemBuilder: (context, p) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '${p.position} ${_jersey(p)}${p.lastName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatPill(label: '${p.ovr}', color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Flips the current format's priority order literally on its head: OVR
/// and POT lead, big and bold, since they're what a GM is actually
/// scanning this picker for (finding a high-potential prospect to
/// individually coach); position/jersey/name/age all trail as one small
/// muted line underneath -- the opposite bet from "name truncates last,"
/// this makes the *stats* the thing that never gets cut off.
class _StatsFirstPicker extends StatelessWidget {
  const _StatsFirstPicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PickerScaffold(
      itemBuilder: (context, p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${p.ovr} OVR · ${p.pot} POT',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${p.position} ${_jersey(p)}${p.lastName} · ${p.age}y',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      selectedItemBuilder: (context, p) =>
          Text('${p.ovr}/${p.pot} · ${p.lastName}'),
    );
  }
}

/// A fixed-width mini-table: position, jersey, OVR, and POT each get a
/// narrow column of their own (numbers right-aligned so they scan like a
/// real stat table instead of a run-on sentence), and only the name
/// column stretches to fill whatever's left -- the only variation here
/// where a long surname can still legitimately run out of room, but
/// unlike the current format, every *other* field is protected by its
/// own fixed column no matter how long the name gets.
class _AlignedColumnsPicker extends StatelessWidget {
  const _AlignedColumnsPicker();

  static Widget _headerCell(
    ThemeData theme,
    String label,
    double width, {
    bool alignRight = false,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(_LabPlayer p) => Row(
      children: [
        SizedBox(width: 28, child: Text(p.position)),
        SizedBox(width: 36, child: Text(_jersey(p).trim())),
        Expanded(child: Text(p.lastName, overflow: TextOverflow.ellipsis)),
        SizedBox(
          width: 44,
          child: Text('${p.ovr}', textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 44,
          child: Text('${p.pot}', textAlign: TextAlign.right),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _headerCell(theme, 'Pos', 28),
              _headerCell(theme, '#', 36),
              const Expanded(child: SizedBox.shrink()),
              _headerCell(theme, 'OVR', 44, alignRight: true),
              _headerCell(theme, 'POT', 44, alignRight: true),
            ],
          ),
        ),
        _PickerScaffold(
          itemBuilder: (context, p) => row(p),
          selectedItemBuilder: (context, p) => row(p),
        ),
      ],
    );
  }
}
