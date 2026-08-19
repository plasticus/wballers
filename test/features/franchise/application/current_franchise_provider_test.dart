import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/coach/domain/coach.dart';
import 'package:womensbballmgr/features/coach/domain/coach_stats.dart';
import 'package:womensbballmgr/features/draft/generation/draft_generator.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/domain/pending_retirement.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/retirement_reason.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/generation/retirement_advancer.dart';
import 'package:womensbballmgr/features/training/domain/training_focus.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';
import '../../roster/domain/roster_test_helpers.dart';

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
  // beginNextSeasonAndPersist reads the bundled portrait catalog
  // (portraitWeightsProvider), same real-asset-loading requirement
  // portrait_catalog_loader_test.dart already established.
  TestWidgetsFlutterBinding.ensureInitialized();

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
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
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
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
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

  test('updateRosterOrder persists the reordered roster', () async {
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
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
      simulationSeed: 1,
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    final reordered = franchise.roster.reversed.toList();
    await container
        .read(currentFranchiseProvider.notifier)
        .updateRosterOrder(reordered);

    final updated = container.read(currentFranchiseProvider).value;
    expect(
      updated?.roster.map((m) => m.player.id).toList(),
      reordered.map((m) => m.player.id).toList(),
    );
  });

  test('updateRosterOrder called before the initial load resolves still '
      'applies once it does -- regression test for a race where state.value '
      'was read before build() had finished', () async {
    final repository = InMemorySaveRepository();
    final franchise = createExpansionFranchise(
      gmName: 'Jordan Ellis',
      clubName: 'Comets',
      homeCity: 'Springfield, IL',
      conference: Conference.atlantic,
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
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
    final reordered = franchise.roster.reversed.toList();
    await container
        .read(currentFranchiseProvider.notifier)
        .updateRosterOrder(reordered);

    final updated = container.read(currentFranchiseProvider).value;
    expect(
      updated?.roster.map((m) => m.player.id).toList(),
      reordered.map((m) => m.player.id).toList(),
    );
  });

  test(
    'updateRosterOrder does nothing when there is no current franchise',
    () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .updateRosterOrder(const []);

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
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
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
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
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

  test(
    'updatePlayerNickname replaces only the targeted player\'s nickname',
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      final targetId = franchise.roster.first.player.id;
      final otherId = franchise.roster[1].player.id;

      await container
          .read(currentFranchiseProvider.notifier)
          .updatePlayerNickname(targetId, 'The Wall');

      final updated = container.read(currentFranchiseProvider).value;
      expect(
        updated!.roster
            .firstWhere((m) => m.player.id == targetId)
            .player
            .nickname,
        'The Wall',
      );
      expect(
        updated.roster
            .firstWhere((m) => m.player.id == otherId)
            .player
            .nickname,
        isNull,
      );
    },
  );

  test('updatePlayerNickname can clear a nickname back to null', () async {
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
      replacedTeamAbbreviation: 'BOS',
      colors: kStarterPalettes.first,
      emoji: '🏀',
      simulationSeed: 1,
    );
    await container
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);
    final targetId = franchise.roster.first.player.id;
    await container
        .read(currentFranchiseProvider.notifier)
        .updatePlayerNickname(targetId, 'The Wall');

    await container
        .read(currentFranchiseProvider.notifier)
        .updatePlayerNickname(targetId, null);

    final updated = container.read(currentFranchiseProvider).value;
    expect(
      updated!.roster
          .firstWhere((m) => m.player.id == targetId)
          .player
          .nickname,
      isNull,
    );
  });

  group('signFreeAgent', () {
    test('moves the player from freeAgents onto the active roster, with a '
        'non-colliding jersey number', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      final target = franchise.freeAgents.first;
      final takenNumbers = franchise.roster
          .map((m) => m.player.jerseyNumber)
          .whereType<int>()
          .toSet();

      await container
          .read(currentFranchiseProvider.notifier)
          .signFreeAgent(target.id);

      final updated = container.read(currentFranchiseProvider).value!;
      final signedMembership = updated.roster.firstWhere(
        (m) => m.player.id == target.id,
      );
      expect(signedMembership.status, RosterStatus.active);
      expect(signedMembership.player.jerseyNumber, isNotNull);
      expect(
        takenNumbers,
        isNot(contains(signedMembership.player.jerseyNumber)),
      );
      expect(updated.freeAgents.any((p) => p.id == target.id), isFalse);
      expect(updated.freeAgents, hasLength(franchise.freeAgents.length - 1));
      expect(
        updated.roster.where((m) => m.status == RosterStatus.active).length,
        franchise.roster.length + 1,
      );
    });

    test('is a no-op once the active roster is already full', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      final stillAvailable = franchise.freeAgents.first;

      await container
          .read(currentFranchiseProvider.notifier)
          .signFreeAgent(stillAvailable.id);

      final updated = container.read(currentFranchiseProvider).value!;
      // Nothing moved -- the roster was already at the cap.
      expect(updated.roster.length, franchise.roster.length);
      expect(updated.freeAgents.length, franchise.freeAgents.length);
    });

    test('is a no-op when the given id isn\'t actually a free agent', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      await container
          .read(currentFranchiseProvider.notifier)
          .signFreeAgent('not-a-real-free-agent-id');

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.roster.length, franchise.roster.length);
      expect(updated.freeAgents.length, franchise.freeAgents.length);
    });

    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .signFreeAgent('whatever');

      expect(container.read(currentFranchiseProvider).value, isNull);
    });
  });

  group('dropPlayer', () {
    test('removes the player from roster and adds them to freeAgents with '
        'their jersey number cleared', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      final target = franchise.roster.first.player;
      expect(target.jerseyNumber, isNotNull); // real roster players do

      await container
          .read(currentFranchiseProvider.notifier)
          .dropPlayer(target.id);

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.roster.any((m) => m.player.id == target.id), isFalse);
      expect(updated.roster, hasLength(franchise.roster.length - 1));
      final droppedPlayer = updated.freeAgents.firstWhere(
        (p) => p.id == target.id,
      );
      expect(droppedPlayer.jerseyNumber, isNull);
      expect(updated.freeAgents, hasLength(franchise.freeAgents.length + 1));

      // Actually persisted, not just held in memory.
      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.roster.any((m) => m.player.id == target.id),
        isFalse,
      );
      expect(savedFranchise.freeAgents.any((p) => p.id == target.id), isTrue);
    });

    test(
      'is a no-op when the given id isn\'t actually on the roster',
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
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        );
        await container
            .read(currentFranchiseProvider.notifier)
            .createFranchise(franchise);

        await container
            .read(currentFranchiseProvider.notifier)
            .dropPlayer('not-a-real-roster-id');

        final updated = container.read(currentFranchiseProvider).value!;
        expect(updated.roster.length, franchise.roster.length);
        expect(updated.freeAgents.length, franchise.freeAgents.length);
      },
    );

    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .dropPlayer('whatever');

      expect(container.read(currentFranchiseProvider).value, isNull);
    });
  });

  group('moveRosterStatus', () {
    test('changes a roster player\'s status and persists it', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      // A young player, eligible for a developmental slot.
      final target = franchise.roster
          .firstWhere((m) => isDevelopmentalEligible(m.player))
          .player;

      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(target.id, RosterStatus.developmental);

      final updated = container.read(currentFranchiseProvider).value!;
      expect(
        updated.roster.firstWhere((m) => m.player.id == target.id).status,
        RosterStatus.developmental,
      );
      // Actually persisted, not just held in memory.
      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.roster
            .firstWhere((m) => m.player.id == target.id)
            .status,
        RosterStatus.developmental,
      );
    });

    test('is a no-op once the target status\'s slot is already full', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      final eligible = franchise.roster
          .where((m) => isDevelopmentalEligible(m.player))
          .take(3)
          .map((m) => m.player.id)
          .toList();
      expect(eligible.length, 3); // needs at least 3 to prove the cap

      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(eligible[0], RosterStatus.developmental);
      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(eligible[1], RosterStatus.developmental);
      // The slot is full (kMaxDevelopmentalRosterSpots == 2) -- this
      // third move should be silently rejected.
      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(eligible[2], RosterStatus.developmental);

      final updated = container.read(currentFranchiseProvider).value!;
      expect(
        updated.roster
            .where((m) => m.status == RosterStatus.developmental)
            .length,
        2,
      );
      expect(
        updated.roster.firstWhere((m) => m.player.id == eligible[2]).status,
        isNot(RosterStatus.developmental),
      );
    });

    test('is a no-op for a player too many years of service for a '
        'developmental slot', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      final veteran = franchise.roster
          .firstWhere((m) => !isDevelopmentalEligible(m.player))
          .player;
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(veteran.id, RosterStatus.developmental);

      final updated = container.read(currentFranchiseProvider).value!;
      expect(
        updated.roster.firstWhere((m) => m.player.id == veteran.id).status,
        isNot(RosterStatus.developmental),
      );
    });

    test(
      'is a no-op when the given id isn\'t actually on the roster',
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
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        );
        await container
            .read(currentFranchiseProvider.notifier)
            .createFranchise(franchise);

        await container
            .read(currentFranchiseProvider.notifier)
            .moveRosterStatus(
              'not-a-real-roster-id',
              RosterStatus.developmental,
            );

        final updated = container.read(currentFranchiseProvider).value!;
        expect(updated.roster.length, franchise.roster.length);
      },
    );

    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus('whatever', RosterStatus.developmental);

      expect(container.read(currentFranchiseProvider).value, isNull);
    });
  });

  group('signFreeAgent with a non-default status', () {
    test('signs a free agent directly into a developmental slot', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      // Not just `.first` -- whichever free agent lands first in the
      // generated pool isn't guaranteed to be developmental-eligible, and
      // signing an ineligible one into a developmental slot is a no-op by
      // design (`current_franchise_provider.dart`'s `_hasOpenSlot`), which
      // would make this test's own assertions fail for the wrong reason.
      final target = franchise.freeAgents.firstWhere(isDevelopmentalEligible);

      await container
          .read(currentFranchiseProvider.notifier)
          .signFreeAgent(target.id, status: RosterStatus.developmental);

      final updated = container.read(currentFranchiseProvider).value!;
      final signed = updated.roster.firstWhere((m) => m.player.id == target.id);
      expect(signed.status, RosterStatus.developmental);
      // The active roster was already full (withFullActiveRoster) -- a
      // developmental signing must not have needed an open active slot.
      expect(
        updated.roster.where((m) => m.status == RosterStatus.active).length,
        franchise.roster.where((m) => m.status == RosterStatus.active).length,
      );
    });

    test('is a no-op signing into a full developmental slot', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      final eligible = franchise.roster
          .where((m) => isDevelopmentalEligible(m.player))
          .take(2)
          .map((m) => m.player.id)
          .toList();
      expect(eligible.length, 2);
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(eligible[0], RosterStatus.developmental);
      await container
          .read(currentFranchiseProvider.notifier)
          .moveRosterStatus(eligible[1], RosterStatus.developmental);
      final target = franchise.freeAgents.first;

      await container
          .read(currentFranchiseProvider.notifier)
          .signFreeAgent(target.id, status: RosterStatus.developmental);

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.roster.any((m) => m.player.id == target.id), isFalse);
      expect(updated.freeAgents.any((p) => p.id == target.id), isTrue);
    });
  });

  group('markMailRead', () {
    test('adds the given id to readMailIds and persists it', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      await container
          .read(currentFranchiseProvider.notifier)
          .markMailRead('assistant_gm_roster_gap');

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.readMailIds, contains('assistant_gm_roster_gap'));

      // Actually persisted, not just held in memory.
      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.readMailIds, contains('assistant_gm_roster_gap'));
    });

    test('is a no-op if the id is already marked read', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      ).copyWithReadMailIds({'already-read'});
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      await container
          .read(currentFranchiseProvider.notifier)
          .markMailRead('already-read');

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.readMailIds, {'already-read'});
    });

    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .markMailRead('whatever');

      expect(container.read(currentFranchiseProvider).value, isNull);
    });
  });

  group('advanceGameDay', () {
    test('returns null when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentFranchiseProvider.future);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .advanceGameDay();

      expect(results, isNull);
    });

    test('returns null while the active roster is short a player -- the '
        'GM has to sign a free agent before the season can advance', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      // Not wrapped in withFullActiveRoster -- 11 active players, exactly
      // the real Day-0 shape.
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
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
          .createFranchise(franchise);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .advanceGameDay();

      expect(results, isNull);
      // Nothing advanced either.
      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.seasonProgress.nextGameDayIndex, 0);
    });

    test('simulates the next game day, persists a lean SeasonProgress, and '
        'returns the full game results for that day', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      final expectedGameDay = gameDaysInOrder(
        franchise.seasonProgress.schedule,
      )[0];
      final expectedGameCount = franchise.seasonProgress.schedule.games
          .where(
            (g) => g.week == expectedGameDay.$1 && g.day == expectedGameDay.$2,
          )
          .length;

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .advanceGameDay();

      expect(results, isNotNull);
      expect(results!.length, expectedGameCount);
      // A real box score, not just a score -- the whole point of returning
      // full GameResults instead of the lean PlayedGames that get persisted.
      expect(results.first.match.events, isNotEmpty);

      final updated = container.read(currentFranchiseProvider).value;
      expect(updated!.seasonProgress.nextGameDayIndex, 1);
      expect(updated.seasonProgress.playedGames.length, expectedGameCount);
    });

    test('is deterministic for a given simulationSeed', () async {
      Franchise freshFranchise() => withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );

      Future<List<int>> playFirstGameDay() async {
        final container = ProviderContainer(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(currentFranchiseProvider.notifier)
            .createFranchise(freshFranchise());
        final results = await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        return [
          for (final result in results!) result.match.homeScore,
          for (final result in results) result.match.awayScore,
        ];
      }

      final a = await playFirstGameDay();
      final b = await playFirstGameDay();

      expect(a, b);
    });

    test('returns null once the season has no game days left to advance '
        'to', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      final totalGameDays = gameDaysInOrder(
        franchise.seasonProgress.schedule,
      ).length;
      final completedFranchise = franchise.copyWithSeasonProgress(
        SeasonProgress(
          schedule: franchise.seasonProgress.schedule,
          playedGames: const [],
          nextGameDayIndex: totalGameDays,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(completedFranchise);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .advanceGameDay();

      expect(results, isNull);
    });
  });

  group('advanceGameDayWithOwnResult', () {
    // An obviously-fabricated score `simulateMatch` would never itself
    // produce -- the clearest possible signal that this exact result (a
    // real live-watched game, not a fresh instant simulation) is what
    // actually gets persisted (2026-08-18, `TODO.md` item 8's live-game
    // architecture stage 5 -- Watch Live).
    const fakeOwnMatch = MatchResult(
      homeScore: 999,
      awayScore: 1,
      homeScoreByQuarter: [999],
      awayScoreByQuarter: [1],
      events: [],
      minutesPlayed: {},
      personalFouls: {},
      fouledOut: {},
      finalEnergy: {},
    );

    test('returns null when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentFranchiseProvider.future);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .advanceGameDayWithOwnResult(fakeOwnMatch);

      expect(results, isNull);
    });

    test('slots the given result into the GM\'s own game, persists a lean '
        'SeasonProgress, and still bulk-simulates every other game the same '
        'day for real', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .advanceGameDayWithOwnResult(fakeOwnMatch);

      expect(results, isNotNull);
      final ownAbbreviation = franchise.team.abbreviation;
      final ownResult = results!.firstWhere(
        (r) =>
            r.game.homeTeamAbbreviation == ownAbbreviation ||
            r.game.awayTeamAbbreviation == ownAbbreviation,
      );
      expect(identical(ownResult.match, fakeOwnMatch), isTrue);

      // At least one other game that day -- a real, freshly-simulated
      // result, not the GM's fabricated one.
      final otherResults = results.where(
        (r) =>
            r.game.homeTeamAbbreviation != ownAbbreviation &&
            r.game.awayTeamAbbreviation != ownAbbreviation,
      );
      expect(otherResults, isNotEmpty);
      for (final other in otherResults) {
        expect(identical(other.match, fakeOwnMatch), isFalse);
      }

      final updated = container.read(currentFranchiseProvider).value;
      expect(updated!.seasonProgress.nextGameDayIndex, 1);
      expect(updated.seasonProgress.playedGames.length, results.length);
    });
  });

  group('simulatePostseasonAndPersist', () {
    test('returns null when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentFranchiseProvider.future);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();

      expect(results, isNull);
    });

    test(
      'returns null while the regular season/Cup still has game days left',
      () async {
        final container = ProviderContainer(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
        );
        addTearDown(container.dispose);
        final franchise = createExpansionFranchise(
          gmName: 'Jordan Ellis',
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
            .createFranchise(franchise);

        final results = await container
            .read(currentFranchiseProvider.notifier)
            .simulatePostseasonAndPersist();

        expect(results, isNull);
      },
    );

    test('once the season is otherwise complete, runs the whole bracket and '
        'persists a champion', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      // Play through every game day (regular season + Continental Cup)
      // until nothing's left to advance day-by-day.
      var progress = franchise.seasonProgress;
      var guard = 0;
      while (!progress.isComplete && guard < 60) {
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        progress = container
            .read(currentFranchiseProvider)
            .value!
            .seasonProgress;
        guard++;
      }
      expect(progress.isComplete, isTrue);

      final results = await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();

      expect(results, isNotNull);
      expect(results, isNotEmpty);

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(
        savedFranchise.seasonProgress.schedule.games.any(
          (g) => g.type == GameType.postseason,
        ),
        isTrue,
      );

      // Calling again is a no-op -- the postseason only ever plays once.
      final again = await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();
      expect(again, isNull);
    });

    test('also resolves the one-time off-season aging lump for a veteran on '
        'the roster (TODO.md item 1)', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      var franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      // Swap in a guaranteed-declining veteran -- generatePlayer's own
      // random age roll doesn't promise one exists on a fresh roster,
      // and this test needs to know for certain the lump has someone
      // real to apply to.
      final veteran = playerWithOverall(70, id: 'veteran-1', age: 34);
      franchise = franchise.copyWithRoster([
        RosterMembership(player: veteran, status: RosterStatus.active),
        ...franchise.roster.skip(1),
      ]);
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      var progress = franchise.seasonProgress;
      var guard = 0;
      while (!progress.isComplete && guard < 60) {
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        progress = container
            .read(currentFranchiseProvider)
            .value!
            .seasonProgress;
        guard++;
      }

      await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.seasonEndAgingResults, isNotEmpty);
      final veteranResult = savedFranchise.seasonEndAgingResults
          .where((r) => r.playerId == 'veteran-1')
          .toList();
      expect(veteranResult, hasLength(1));
      expect(veteranResult.single.overallDelta, lessThan(0));
      final restoredVeteran = savedFranchise.roster
          .firstWhere((m) => m.player.id == 'veteran-1')
          .player;
      expect(restoredVeteran.ratings.overall, lessThan(70));
    });

    test('a GM-own-roster player who hits the mandatory retirement age '
        'becomes a pending decision, not an automatic removal (2026-08-11, '
        '0D_Season_2_Roadmap.md: Aging & roster churn)', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      var franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      final elder = playerWithOverall(
        70,
        id: 'elder-1',
        age: kMandatoryRetirementAge,
      );
      franchise = franchise.copyWithRoster([
        RosterMembership(player: elder, status: RosterStatus.active),
        ...franchise.roster.skip(1),
      ]);
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      var progress = franchise.seasonProgress;
      var guard = 0;
      while (!progress.isComplete && guard < 60) {
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        progress = container
            .read(currentFranchiseProvider)
            .value!
            .seasonProgress;
        guard++;
      }

      await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();

      final updated = container.read(currentFranchiseProvider).value!;
      // Still on the roster -- the GM hasn't decided anything yet.
      expect(updated.roster.any((m) => m.player.id == 'elder-1'), isTrue);
      final pending = updated.pendingRetirements.where(
        (p) => p.playerId == 'elder-1',
      );
      expect(pending, hasLength(1));
      expect(pending.single.reason, RetirementReason.hitMandatoryAge);
    });

    test('also trains every AI team\'s roster, all at once, once the '
        'postseason resolves (TODO.md item 8, a direct GM ask -- "all AI '
        'training... at the end of the season... in one big lump")', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      var progress = franchise.seasonProgress;
      var guard = 0;
      while (!progress.isComplete && guard < 60) {
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        progress = container
            .read(currentFranchiseProvider)
            .value!
            .seasonProgress;
        guard++;
      }

      await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );

      // A real, full 310-game season gives every AI roster real minutes
      // for real players across ~18-21 training-eligible weeks -- across
      // 19 teams x 12 players, at least someone's ratings moved.
      var anyAiPlayerChanged = false;
      outer:
      for (var i = 0; i < franchise.league.aiTeams.length; i++) {
        final before = franchise.league.aiTeams[i].roster;
        final after = savedFranchise.league.aiTeams[i].roster;
        for (var j = 0; j < before.length; j++) {
          if (before[j].player.ratings.overall !=
                  after[j].player.ratings.overall ||
              before[j].player.id != after[j].player.id) {
            // An id mismatch here would itself be a real bug (roster
            // reordering), not just "no growth" -- either way, this
            // player counts as evidence the pass actually ran.
            anyAiPlayerChanged = true;
            break outer;
          }
        }
      }
      expect(anyAiPlayerChanged, isTrue);

      // Team identity is never touched by training -- same 19 teams.
      // Roster *composition* is a little looser: `simulatePostseasonAndPersist`
      // bundles real AI-team retirement into this same call
      // (`resolveAiTeamRetirements`, entirely separate from training
      // itself), which can genuinely remove a player -- surfaced by this
      // exact test once the name pools grew (2026-08-19, a direct GM
      // ask to fold in more names), which shifted which players this
      // fixed seed generates in the first place. What training itself
      // actually guarantees, and what's worth still checking here: no
      // reordering, no duplication, no player appearing who wasn't
      // already on the original roster -- the after-roster is always a
      // (possibly shorter) ordered subsequence of the before-roster.
      expect(savedFranchise.league.aiTeams.length, 19);
      for (var i = 0; i < franchise.league.aiTeams.length; i++) {
        expect(
          savedFranchise.league.aiTeams[i].team.abbreviation,
          franchise.league.aiTeams[i].team.abbreviation,
        );
        final beforeIds = franchise.league.aiTeams[i].roster
            .map((m) => m.player.id)
            .toList();
        final afterIds = savedFranchise.league.aiTeams[i].roster
            .map((m) => m.player.id)
            .toList();
        var cursor = 0;
        for (final id in afterIds) {
          final foundAt = beforeIds.indexOf(id, cursor);
          expect(
            foundAt,
            greaterThanOrEqualTo(0),
            reason:
                'team ${franchise.league.aiTeams[i].team.abbreviation}: '
                '$id appeared out of order, or wasn\'t on the original '
                'roster at all',
          );
          cursor = foundAt + 1;
        }
      }
    });

    test('also resolves this season\'s real awards once the postseason '
        'wraps (2026-08-11, 0D_Season_2_Roadmap.md: Presentation)', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      var progress = franchise.seasonProgress;
      var guard = 0;
      while (!progress.isComplete && guard < 60) {
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        progress = container
            .read(currentFranchiseProvider)
            .value!
            .seasonProgress;
        guard++;
      }

      await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();

      final updated = container.read(currentFranchiseProvider).value!;
      // A real, full season across 20 teams should crown a League MVP at
      // minimum -- confirms the pass actually ran as part of the real
      // pipeline, not just in isolation (season_awards_advancer_test.dart
      // already covers the award logic itself in detail).
      final everyPlayer = [
        ...updated.roster.map((m) => m.player),
        for (final aiTeam in updated.league.aiTeams)
          ...aiTeam.roster.map((m) => m.player),
      ];
      expect(
        everyPlayer.any(
          (p) =>
              p.achievements.any((a) => a.achievement == Achievement.leagueMvp),
        ),
        isTrue,
      );
    });
  });

  group('updateTrainingPlan', () {
    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(currentFranchiseProvider.notifier)
          .updateTrainingPlan(TrainingPlan.initial());

      expect(container.read(currentFranchiseProvider).value, isNull);
    });

    test('replaces the training plan and persists it', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      final newPlan = TrainingPlan.initial().copyWithTeamFocus(
        TrainingFocus.offense,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .updateTrainingPlan(newPlan);

      expect(
        container.read(currentFranchiseProvider).value?.trainingPlan.teamFocus,
        TrainingFocus.offense,
      );
      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.trainingPlan.teamFocus, TrainingFocus.offense);
    });
  });

  group('runTrainingAndPersist', () {
    test('returns null when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentFranchiseProvider.future);

      final report = await container
          .read(currentFranchiseProvider.notifier)
          .runTrainingAndPersist();

      expect(report, isNull);
    });

    test('returns null before a full training week has been played', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      final franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
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
          .createFranchise(franchise);

      final report = await container
          .read(currentFranchiseProvider.notifier)
          .runTrainingAndPersist();

      expect(report, isNull);
    });

    test('advanceGameDay auto-resolves training the moment the preseason '
        'week completes, so this becomes a no-op right after', () async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      // The preseason (week 1) has 2 game days (Sunday, Thursday) --
      // both need to be played before the week counts as fully complete.
      // advanceGameDay itself resolves training for week 1 as soon as
      // the second call completes it (see `_catchUpTraining`'s doc
      // comment on `current_franchise_provider.dart`) -- no separate
      // resolve step needed anymore.
      await container.read(currentFranchiseProvider.notifier).advanceGameDay();
      await container.read(currentFranchiseProvider.notifier).advanceGameDay();

      final updated = container.read(currentFranchiseProvider).value;
      expect(updated!.nextTrainingWeek, 2);
      expect(updated.trainingReports, hasLength(1));
      expect(updated.trainingReports.single.week, 1);

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.nextTrainingWeek, 2);
      expect(savedFranchise.trainingReports, hasLength(1));

      // Already resolved by advanceGameDay -- an explicit call now is a
      // no-op.
      final again = await container
          .read(currentFranchiseProvider.notifier)
          .runTrainingAndPersist();
      expect(again, isNull);
    });

    test('catches up every completed week individually, not just the most '
        'recent one, when several game days are advanced in a row', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      // Play through several game days in one burst, the way a GM who
      // doesn't check the Dashboard after every single day would --
      // nothing in between ever calls runTrainingAndPersist.
      for (var i = 0; i < 6; i++) {
        final result = await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        if (result == null) break;
      }

      final updated = container.read(currentFranchiseProvider).value!;
      final weeks = updated.trainingReports.map((r) => r.week).toList();
      // Every fully-completed week got its own report -- no week
      // silently missing because it fell inside a multi-day burst, and
      // no duplicate/merged entries either.
      expect(weeks, weeks.toSet().toList());
      expect(
        updated.nextTrainingWeek,
        weeks.isEmpty ? 1 : weeks.reduce((a, b) => a > b ? a : b) + 1,
      );
    });

    test('is deterministic for a given simulationSeed', () async {
      Franchise freshFranchise() => withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );

      Future<int> playWeekAndTrain() async {
        final container = ProviderContainer(
          overrides: [
            saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(currentFranchiseProvider.notifier)
            .createFranchise(freshFranchise());
        // advanceGameDay auto-resolves week 1's training the moment the
        // second call completes it -- see `_catchUpTraining`.
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        final report = container
            .read(currentFranchiseProvider)
            .value!
            .trainingReports
            .single;
        return report.results.fold<int>(
          0,
          (sum, r) => sum + r.fieldDeltas.values.fold<int>(0, (a, b) => a + b),
        );
      }

      final a = await playWeekAndTrain();
      final b = await playWeekAndTrain();

      expect(a, b);
    });
  });

  group('resolvePendingRetirement', () {
    Future<ProviderContainer> containerWithPending({
      required Player player,
      required int motivation,
    }) async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      var franchise = createExpansionFranchise(
        gmName: 'Jordan Ellis',
        clubName: 'Comets',
        homeCity: 'Springfield, IL',
        conference: Conference.atlantic,
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      franchise = franchise
          .copyWithCoach(
            Coach(
              name: franchise.coach.name,
              stats: CoachStats(
                offense: 50,
                defense: 50,
                development: 50,
                motivation: motivation,
                management: 50,
              ),
              archetype: franchise.coach.archetype,
            ),
          )
          .copyWithRoster([
            RosterMembership(player: player, status: RosterStatus.active),
            ...franchise.roster.skip(1),
          ])
          .copyWithPendingRetirements([
            PendingRetirement(
              playerId: player.id,
              reason: RetirementReason.hitMandatoryAge,
            ),
          ]);
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);
      return container;
    }

    test('letting a player retire removes them from the roster, not into '
        'freeAgents, and clears the pending entry', () async {
      final player = playerWithOverall(70, id: 'p1', age: 38);
      final container = await containerWithPending(
        player: player,
        motivation: 50,
      );

      final outcome = await container
          .read(currentFranchiseProvider.notifier)
          .resolvePendingRetirement('p1', attemptPersuasion: false);

      expect(outcome, RetirementDecisionOutcome.letRetire);
      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.roster.any((m) => m.player.id == 'p1'), isFalse);
      expect(updated.freeAgents.any((p) => p.id == 'p1'), isFalse);
      expect(updated.pendingRetirements, isEmpty);
    });

    test('attempting persuasion always clears the pending entry, and the '
        'reported outcome always matches whether the player is still on '
        'the roster', () async {
      // Motivation 50 -> chance ~0.5, so both outcomes are reachable
      // within a handful of fresh attempts -- no seed control over the
      // provider's internal Random(), so this asserts self-consistency
      // (outcome always matches roster state) across enough tries to
      // see both branches, rather than forcing one specific branch.
      final seenOutcomes = <RetirementDecisionOutcome>{};
      for (var i = 0; i < 40 && seenOutcomes.length < 2; i++) {
        final player = playerWithOverall(70, id: 'p1', age: 38);
        final container = await containerWithPending(
          player: player,
          motivation: 50,
        );

        final outcome = await container
            .read(currentFranchiseProvider.notifier)
            .resolvePendingRetirement('p1', attemptPersuasion: true);
        final updated = container.read(currentFranchiseProvider).value!;
        final stillRostered = updated.roster.any((m) => m.player.id == 'p1');

        expect(updated.pendingRetirements, isEmpty);
        if (outcome == RetirementDecisionOutcome.persuadedToStay) {
          expect(stillRostered, isTrue);
        } else {
          expect(outcome, RetirementDecisionOutcome.persuasionFailed);
          expect(stillRostered, isFalse);
          expect(updated.freeAgents.any((p) => p.id == 'p1'), isFalse);
        }
        seenOutcomes.add(outcome!);
      }

      expect(
        seenOutcomes,
        {
          RetirementDecisionOutcome.persuadedToStay,
          RetirementDecisionOutcome.persuasionFailed,
        },
        reason: 'expected both outcomes to occur within 40 fresh attempts',
      );
    });

    test('is a no-op (returns null) when the given id isn\'t actually '
        'pending', () async {
      final player = playerWithOverall(70, id: 'p1', age: 38);
      final container = await containerWithPending(
        player: player,
        motivation: 50,
      );

      final outcome = await container
          .read(currentFranchiseProvider.notifier)
          .resolvePendingRetirement('not-pending', attemptPersuasion: false);

      expect(outcome, isNull);
      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.pendingRetirements, hasLength(1));
    });

    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(currentFranchiseProvider.notifier)
          .resolvePendingRetirement('whatever', attemptPersuasion: false);

      expect(outcome, isNull);
      expect(container.read(currentFranchiseProvider).value, isNull);
    });
  });

  group('beginNextSeasonAndPersist / makeDraftPick (2026-08-11, '
      '0D_Season_2_Roadmap.md: The draft, for real)', () {
    /// Creates a franchise, persists it, and plays it all the way through
    /// season 0's postseason via the real provider -- same
    /// play-every-game-day-then-postseason pattern the
    /// `simulatePostseasonAndPersist` group above already established,
    /// just packaged for reuse here too.
    Future<ProviderContainer> playedOutContainer() async {
      final repository = InMemorySaveRepository();
      final container = ProviderContainer(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final franchise = withFullActiveRoster(
        createExpansionFranchise(
          gmName: 'Jordan Ellis',
          clubName: 'Comets',
          homeCity: 'Springfield, IL',
          conference: Conference.atlantic,
          replacedTeamAbbreviation: 'BOS',
          colors: kStarterPalettes.first,
          emoji: '🏀',
          simulationSeed: 1,
        ),
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      var progress = franchise.seasonProgress;
      var guard = 0;
      while (!progress.isComplete && guard < 60) {
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        progress = container
            .read(currentFranchiseProvider)
            .value!
            .seasonProgress;
        guard++;
      }
      await container
          .read(currentFranchiseProvider.notifier)
          .simulatePostseasonAndPersist();
      return container;
    }

    test('does nothing when there is no current franchise', () async {
      final container = ProviderContainer(
        overrides: [
          saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentFranchiseProvider.future);

      await container
          .read(currentFranchiseProvider.notifier)
          .beginNextSeasonAndPersist();

      expect(container.read(currentFranchiseProvider).value, isNull);
    });

    test('does nothing when the season isn\'t actually over yet', () async {
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
        replacedTeamAbbreviation: 'BOS',
        colors: kStarterPalettes.first,
        emoji: '🏀',
        simulationSeed: 1,
      );
      await container
          .read(currentFranchiseProvider.notifier)
          .createFranchise(franchise);

      await container
          .read(currentFranchiseProvider.notifier)
          .beginNextSeasonAndPersist();

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.season, 0);
      expect(updated.draftInProgress, isNull);
    });

    test('transitions to season 1 with a draftInProgress already resolved '
        'up to the GM\'s own first turn', () async {
      final container = await playedOutContainer();

      await container
          .read(currentFranchiseProvider.notifier)
          .beginNextSeasonAndPersist();

      final updated = container.read(currentFranchiseProvider).value!;
      expect(updated.season, 1);
      expect(updated.draftInProgress, isNotNull);
      expect(
        updated.draftInProgress!.onTheClock,
        updated.team.abbreviation,
        reason:
            'AI picks between the start of the draft and the GM\'s own '
            'first turn should already be resolved',
      );
    });

    test(
      'makeDraftPick does nothing when there is no draft in progress',
      () async {
        final container = await playedOutContainer();
        final before = container.read(currentFranchiseProvider).value!;

        await container
            .read(currentFranchiseProvider.notifier)
            .makeDraftPick('whoever');

        final after = container.read(currentFranchiseProvider).value!;
        expect(after.roster.length, before.roster.length);
      },
    );

    test('makeDraftPick does nothing for a prospect id that isn\'t in the '
        'draft class', () async {
      final container = await playedOutContainer();
      await container
          .read(currentFranchiseProvider.notifier)
          .beginNextSeasonAndPersist();
      final before = container.read(currentFranchiseProvider).value!;

      await container
          .read(currentFranchiseProvider.notifier)
          .makeDraftPick('not-a-real-prospect');

      final after = container.read(currentFranchiseProvider).value!;
      expect(
        after.draftInProgress!.picks.length,
        before.draftInProgress!.picks.length,
      );
    });

    test('a full draft can be played out end-to-end: every own pick lands '
        'on the roster, and both draftInProgress and draftClass end up '
        'empty', () async {
      final container = await playedOutContainer();
      await container
          .read(currentFranchiseProvider.notifier)
          .beginNextSeasonAndPersist();

      var franchise = container.read(currentFranchiseProvider).value!;
      final rosterCountBeforeDraft = franchise.roster.length;
      final aiRosterCountBeforeDraft = franchise.league.aiTeams.fold<int>(
        0,
        (sum, aiTeam) => sum + aiTeam.roster.length,
      );
      var ownPicksMade = 0;
      var guard = 0;
      while (franchise.draftInProgress != null && guard < 10) {
        expect(
          franchise.draftInProgress!.onTheClock,
          franchise.team.abbreviation,
        );
        final pickedIds = {
          for (final pick in franchise.draftInProgress!.picks)
            pick.prospect.player.id,
        };
        final best = franchise.draftClass
            .where((p) => !pickedIds.contains(p.player.id))
            .reduce(
              (a, b) => draftProspectValue(a) >= draftProspectValue(b) ? a : b,
            );
        await container
            .read(currentFranchiseProvider.notifier)
            .makeDraftPick(best.player.id);
        franchise = container.read(currentFranchiseProvider).value!;
        ownPicksMade++;
        guard++;
      }

      expect(ownPicksMade, kDraftRounds);
      expect(franchise.draftInProgress, isNull);
      expect(franchise.draftClass, isEmpty);
      expect(franchise.roster.length, rosterCountBeforeDraft + kDraftRounds);
      // Every AI team should also have gained players -- a real draft
      // refreshes the whole league, not just the GM's own roster.
      final aiRosterCountAfterDraft = franchise.league.aiTeams.fold<int>(
        0,
        (sum, aiTeam) => sum + aiTeam.roster.length,
      );
      expect(
        aiRosterCountAfterDraft,
        aiRosterCountBeforeDraft + 19 * kDraftRounds,
      );
    });
  });
}
