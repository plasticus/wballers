import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/training/domain/training_focus.dart';
import 'package:womensbballmgr/features/training/domain/training_plan.dart';

import '../../../support/franchise_test_helpers.dart';
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

    test('once the preseason week is fully played, resolves training and '
        'persists the result', () async {
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
      await container.read(currentFranchiseProvider.notifier).advanceGameDay();
      await container.read(currentFranchiseProvider.notifier).advanceGameDay();

      final report = await container
          .read(currentFranchiseProvider.notifier)
          .runTrainingAndPersist();

      expect(report, isNotNull);
      expect(report!.week, 1);

      final updated = container.read(currentFranchiseProvider).value;
      expect(updated!.nextTrainingWeek, 2);
      expect(updated.trainingReports, hasLength(1));

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.nextTrainingWeek, 2);
      expect(savedFranchise.trainingReports, hasLength(1));

      // Calling again before the next week completes is a no-op.
      final again = await container
          .read(currentFranchiseProvider.notifier)
          .runTrainingAndPersist();
      expect(again, isNull);
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
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        await container
            .read(currentFranchiseProvider.notifier)
            .advanceGameDay();
        final report = await container
            .read(currentFranchiseProvider.notifier)
            .runTrainingAndPersist();
        return report!.results.fold<int>(
          0,
          (sum, r) => sum + r.fieldDeltas.values.fold<int>(0, (a, b) => a + b),
        );
      }

      final a = await playWeekAndTrain();
      final b = await playWeekAndTrain();

      expect(a, b);
    });
  });
}
