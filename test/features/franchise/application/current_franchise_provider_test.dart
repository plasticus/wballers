import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/roster/domain/starting_lineup.dart';

import '../../../support/in_memory_save_repository.dart';

const _newAppearance = PortraitAppearance(
  version: 2,
  baseSprite: kDefaultBaseSprite,
  skinTone: 'chocolate',
  hairColor: 'gray',
  eyes: 'eyes_wide',
  nose: 'nose_hook',
  mouth: 'mouth_9',
  isCoach: false,
);

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

  test('updateCoachAppearance persists a new coach appearance', () async {
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

    await container
        .read(currentFranchiseProvider.notifier)
        .updateCoachAppearance(_newAppearance);

    final updated = container.read(currentFranchiseProvider).value;
    expect(updated?.coach.appearance?.skinTone, 'chocolate');
    expect(updated?.coach.appearance?.version, 2);
    // Every other coach field is untouched.
    expect(updated?.coach.name, franchise.coach.name);
    expect(updated?.coach.stats.overall, franchise.coach.stats.overall);
  });

  test('updatePlayerAppearance replaces only the targeted player', () async {
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
    final targetId = franchise.roster.first.player.id;
    final otherPlayer = franchise.roster[1].player;

    await container
        .read(currentFranchiseProvider.notifier)
        .updatePlayerAppearance(targetId, _newAppearance);

    final updated = container.read(currentFranchiseProvider).value;
    final updatedTarget = updated!.roster.firstWhere(
      (m) => m.player.id == targetId,
    );
    final updatedOther = updated.roster.firstWhere(
      (m) => m.player.id == otherPlayer.id,
    );
    expect(updatedTarget.player.appearance?.skinTone, 'chocolate');
    expect(updatedOther.player.appearance, otherPlayer.appearance);
  });

  test(
    'updatePlayerAppearance does nothing when the player id is not on the roster',
    () async {
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

      await container
          .read(currentFranchiseProvider.notifier)
          .updatePlayerAppearance('not-a-real-id', _newAppearance);

      final updated = container.read(currentFranchiseProvider).value;
      for (var i = 0; i < updated!.roster.length; i++) {
        expect(
          updated.roster[i].player.appearance,
          franchise.roster[i].player.appearance,
        );
      }
    },
  );
}
