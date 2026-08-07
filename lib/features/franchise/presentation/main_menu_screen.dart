import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/wbl_logo.dart';
import '../../dashboard/dashboard_screen.dart';
import '../application/save_slots.dart';
import '../domain/franchise.dart';

/// The title-screen slot picker -- reachable from `SettingsScreen`'s
/// "Exit to Main Menu" (2026-08-07, a direct GM ask: "Exit to Main Menu,
/// and the Main Menu is that screen where it's got kind of the splash
/// screen, and you click to start a new expansion franchise... 3 save
/// slots, and the ability to delete a save slot"). Not the app's normal
/// boot screen -- `WomensBasketballManagerApp.home` is still `AppShell`,
/// so a GM who never opens Settings never sees this at all, same as
/// before multi-slot support existed.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Center(child: WblLogo(size: 96)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Women\'s Basketball Manager',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose a save to play, or start a new one.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < kSaveSlotIds.length; i++) ...[
                      _SaveSlotCard(slotId: kSaveSlotIds[i], slotNumber: i + 1),
                      if (i != kSaveSlotIds.length - 1)
                        const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveSlotCard extends ConsumerWidget {
  const _SaveSlotCard({required this.slotId, required this.slotNumber});

  final String slotId;
  final int slotNumber;

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    await ref.read(activeSaveSlotProvider.notifier).setActiveSlot(slotId);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Franchise franchise,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this save?'),
        content: Text(
          '${franchise.team.name} will be gone for good -- this can\'t '
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteSaveSlot(ref, slotId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final franchiseAsync = ref.watch(saveSlotFranchiseProvider(slotId));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Slot $slotNumber', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          switch (franchiseAsync) {
            AsyncData(:final value?) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      value.team.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        value.team.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                Text('GM ${value.gmName}', style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _play(context, ref),
                        child: const Text('Play'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => _confirmDelete(context, ref, value),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            AsyncData() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Empty',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => _play(context, ref),
                  child: const Text('Play'),
                ),
              ],
            ),
            AsyncError() => Text(
              'Could not load this save.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            _ => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}
