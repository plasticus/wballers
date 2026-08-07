import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/application/save_slots.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';

import '../../../support/in_memory_save_repository.dart';

void main() {
  group('activeSaveSlotProvider', () {
    test('defaults to slot 1 (kCurrentFranchiseSaveId) when nothing has '
        'been chosen', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final slot = await container.read(activeSaveSlotProvider.future);

      expect(slot, kCurrentFranchiseSaveId);
      expect(slot, kSaveSlotIds.first);
    });

    test('setActiveSlot switches and persists the choice', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(activeSaveSlotProvider.future);

      await container
          .read(activeSaveSlotProvider.notifier)
          .setActiveSlot('franchise-slot-2');

      expect(container.read(activeSaveSlotProvider).value, 'franchise-slot-2');
      // Actually persisted, not just held in memory -- a fresh container
      // reading the same repository picks it back up.
      final freshContainer = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(freshContainer.dispose);
      expect(
        await freshContainer.read(activeSaveSlotProvider.future),
        'franchise-slot-2',
      );
    });

    test('switching slots makes currentFranchiseProvider load the new '
        'slot\'s franchise', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final slot1Franchise = createExpansionFranchise(
        gmName: 'Slot 1 GM',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(slot1Franchise);
      expect(container.read(currentFranchiseProvider).value, isNotNull);

      await container
          .read(activeSaveSlotProvider.notifier)
          .setActiveSlot('franchise-slot-2');
      // Slot 2 has nothing in it yet.
      final reloaded = await container.read(currentFranchiseProvider.future);
      expect(reloaded, isNull);
    });
  });

  group('saveSlotFranchiseProvider', () {
    test('reads a slot directly, independent of the active slot', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      // Never switch the active slot -- write straight into slot 2 by
      // switching, creating, then switching back, to seed it.
      await container
          .read(activeSaveSlotProvider.notifier)
          .setActiveSlot('franchise-slot-2');
      final slot2Franchise = createExpansionFranchise(
        gmName: 'Slot 2 GM',
        clubName: 'Rockets',
        homeCity: 'Metro City',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🚀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(slot2Franchise);
      await container
          .read(activeSaveSlotProvider.notifier)
          .setActiveSlot(kCurrentFranchiseSaveId);

      final slot2 = await container.read(
        saveSlotFranchiseProvider('franchise-slot-2').future,
      );
      expect(slot2?.gmName, 'Slot 2 GM');

      final emptySlot3 = await container.read(
        saveSlotFranchiseProvider('franchise-slot-3').future,
      );
      expect(emptySlot3, isNull);
    });
  });

  // deleteSaveSlot itself takes a WidgetRef (UI-only), so it's exercised
  // end to end via the Delete button in main_menu_screen_test.dart rather
  // than here.
}
