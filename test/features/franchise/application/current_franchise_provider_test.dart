import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import '../../../support/in_memory_save_repository.dart';

void main() {
  test('starts as null when nothing has been saved', () async {
    final container = ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
      ],
    );
    addTearDown(container.dispose);

    final franchise = await container.read(currentFranchiseProvider.future);

    expect(franchise, isNull);
  });

  test('createFranchise persists and updates state', () async {
    final repository = InMemorySaveRepository();
    final container = ProviderContainer(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(currentFranchiseProvider.future);

    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      simulationSeed: 1,
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    expect(container.read(currentFranchiseProvider).value?.team.name, 'Comets');
    expect(await repository.readSave(kCurrentFranchiseSaveId), isNotNull);
  });

  test('a franchise survives being reloaded by a fresh container', () async {
    final repository = InMemorySaveRepository();
    final firstContainer = ProviderContainer(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
    );
    await firstContainer.read(currentFranchiseProvider.future);
    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      simulationSeed: 1,
    );
    await firstContainer
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);
    firstContainer.dispose();

    final secondContainer = ProviderContainer(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(secondContainer.dispose);

    final reloaded = await secondContainer.read(
      currentFranchiseProvider.future,
    );

    expect(reloaded?.team.name, 'Comets');
    expect(reloaded?.gmName, 'Jordan Ellis');
  });

  test('updateLineup persists a new lineup', () async {
    final repository = InMemorySaveRepository();
    final container = ProviderContainer(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      simulationSeed: 1,
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    const newLineup = StartingLineup(
      startersByPosition: {Position.pointGuard: 'someone-else'},
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .updateLineup(newLineup);

    expect(
      container
          .read(currentFranchiseProvider)
          .value
          ?.startingLineup
          .startersByPosition,
      newLineup.startersByPosition,
    );
  });

  test('updateLineup called before the initial load resolves still applies '
      'once it does -- regression test for a race where state.value was '
      'read before build() had finished', () async {
    final repository = InMemorySaveRepository();
    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      simulationSeed: 1,
    );
    final envelope = SaveEnvelope(
      schemaVersion: 1,
      payload: franchiseToJson(franchise),
    );
    await repository.writeSave(kCurrentFranchiseSaveId, envelope.toJson());

    final container = ProviderContainer(
      overrides: [saveRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    // Deliberately not awaiting the initial load first.
    const newLineup = StartingLineup(
      startersByPosition: {Position.pointGuard: 'someone-else'},
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .updateLineup(newLineup);

    expect(
      container
          .read(currentFranchiseProvider)
          .value
          ?.startingLineup
          .startersByPosition,
      newLineup.startersByPosition,
    );
  });

  test(
    'updateLineup does nothing when there is no current franchise',
    () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .updateLineup(const StartingLineup(startersByPosition: {}));

      expect(container.read(currentFranchiseProvider).value, isNull);
    },
  );
}
