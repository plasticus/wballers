import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_preferences.dart';
import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/presentation/main_menu_screen.dart';
import '../../match/presentation/live_game_lab_screen.dart';
import '../../training/presentation/coach_picker_lab_screen.dart';

/// Settings, reachable from the top-right of every `AppShell` tab
/// (2026-08-07, a direct GM ask: "let's also get a settings button going
/// in the upper right"). Wires up the 2 real preferences that already
/// had backing state with nowhere to be set from
/// (`app/app_preferences.dart`'s own doc comments flagged both as
/// waiting on exactly this screen) -- text size directly serves the
/// GM's own low-vision accessibility need, so it's real and working, not
/// a placeholder. Ad preferences are a true placeholder (disabled --
/// there's no ad system yet, Phase 5). "Exit to Main Menu" is the other
/// concrete ask: originally floated as "a button to blow up the current
/// save and start over," reframed into the softer, non-destructive
/// `MainMenuScreen` slot picker instead, per the GM's own "or better
/// yet" follow-up in the same message.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textScale = ref.watch(textScaleProvider);
    final themeModePreference = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Display', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Text Size', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Layered on top of your device\'s own text size '
                    'setting.',
                    style: theme.textTheme.bodySmall,
                  ),
                  Slider(
                    value: textScale,
                    min: 0.8,
                    max: 1.8,
                    divisions: 20,
                    label: '${(textScale * 100).round()}%',
                    onChanged: (value) =>
                        ref.read(textScaleProvider.notifier).state = value,
                  ),
                  Text(
                    'Sample text at this size.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ThemeModePreference>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeModePreference.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeModePreference.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeModePreference.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeModePreference},
                    onSelectionChanged: (selection) =>
                        ref.read(themeModeProvider.notifier).state =
                            selection.first,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Coming Soon', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const AppCard(
              child: ListTile(
                enabled: false,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.smart_display_outlined),
                title: Text('Ad-Supported Play'),
                subtitle: Text(
                  'Watch a short ad for a temporary in-game boost.',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Developer', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A dev-only design lab -- not a real feature, no '
                    'save-file effect. Comparing 3 ways to present a '
                    'live, in-progress game (TODO.md item 8).',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LiveGameLabScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.sports_basketball_outlined),
                    label: const Text('Live Game Lab'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Moved here from the Training screen (2026-08-18, a
                  // direct GM ask to hide it from that real gameplay
                  // screen) -- a dev-facing comparison tool, not a real
                  // setting; see `coach_picker_lab_screen.dart`'s own doc
                  // comment (2026-08-10, TODO.md item 5). #3 "Stat Chips"
                  // landed as the real picker on the Training screen
                  // (2026-08-11); kept around here as a reference/
                  // comparison tool, same posture as the Live Game Lab
                  // above.
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CoachPickerLabScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Coach Picker Lab'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Save Data', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Switch to a different save slot, start a new one, or '
                    'delete one you\'re done with.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const MainMenuScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit to Main Menu'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
