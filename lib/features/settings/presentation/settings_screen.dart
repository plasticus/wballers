import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_preferences.dart';
import '../../../app/app_spacing.dart';
import '../../../app/build_info.dart';
import '../../../core/widgets/app_card.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../franchise/application/debug_test_save.dart';
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
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _isGeneratingTestSave = false;

  Future<void> _loadNearEndOfSeasonTestSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Load Test Save?'),
        content: Text(
          'Generates a fresh franchise, fast-forwarded to '
          '$kDebugTestSaveGameDaysRemaining games left before the '
          'postseason, and switches to it -- overwrites whatever is in '
          'Slot 3. Your other 2 save slots are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Load'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isGeneratingTestSave = true);
    await generateNearEndOfSeasonTestSave(ref);
    if (!mounted) return;
    setState(() => _isGeneratingTestSave = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = ref.watch(textScaleProvider);
    final themeModePreference = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // At the very top, deliberately -- a direct GM report
            // (2026-08-21): "I feel like [an install not landing] has
            // happened a few times, now... Maybe we could put a version
            // number on the settings menu, and I can check it after
            // every build." [kAppBuildStamp] is the git commit a build
            // was actually cut from, so it's independently checkable
            // against `git log` -- not a monotonic build counter, which
            // would only prove *a* build landed, not *which* one.
            Text('App Version', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Text(kAppBuildStamp, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: AppSpacing.xl),
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
                  const SizedBox(height: AppSpacing.sm),
                  // A direct GM ask (2026-08-21): "I need to develop an
                  // admin save-game that fires up with like... 3 games
                  // left in the season. So I can test off-season
                  // faster." Unlike the 2 labs above, this one DOES have
                  // a real save-file effect -- see
                  // `generateNearEndOfSeasonTestSave`'s own doc comment
                  // for why it's confined to a fixed scratch slot rather
                  // than risking a real playthrough.
                  OutlinedButton.icon(
                    onPressed: _isGeneratingTestSave
                        ? null
                        : _loadNearEndOfSeasonTestSave,
                    icon: _isGeneratingTestSave
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fast_forward_outlined),
                    label: Text(
                      _isGeneratingTestSave
                          ? 'Generating...'
                          : 'Load Test Save ($kDebugTestSaveGameDaysRemaining '
                                'Games Left)',
                    ),
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
