import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/player/domain/achievement.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/generation/all_star_generator.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

void main() {
  test('advancing through the All-Star break resolves the Skills Competition '
      'and the All-Star Game, granting the MVP a real achievement '
      '(2026-08-10, TODO.md items 5/6)', () async {
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

    // Play every game day up to (but not through) the All-Star week --
    // the generic advanceGameDay() would silently skip both All-Star
    // days if let through (`season_advancer.dart`'s `_simulatable`), so
    // this stops right before them to exercise the dedicated methods
    // instead.
    var progress = container
        .read(currentFranchiseProvider)
        .value!
        .seasonProgress;
    var guard = 0;
    while (!nextGameDayTypes(progress).contains(GameType.skillsCompetition) &&
        guard < 60) {
      await container.read(currentFranchiseProvider.notifier).advanceGameDay();
      progress = container.read(currentFranchiseProvider).value!.seasonProgress;
      guard++;
    }
    expect(
      nextGameDayTypes(progress).contains(GameType.skillsCompetition),
      isTrue,
      reason: 'guard exhausted before reaching the All-Star week',
    );

    final skillsResult = await container
        .read(currentFranchiseProvider.notifier)
        .advanceSkillsCompetitionDay();

    expect(skillsResult, isNotNull);
    expect(skillsResult!.week, kAllStarWeek);
    expect(skillsResult.squads[Conference.atlantic], hasLength(10));
    expect(skillsResult.squads[Conference.pacific], hasLength(10));
    expect(skillsResult.events, hasLength(3));
    for (final event in skillsResult.events) {
      expect(event.standings, isNotEmpty);
      expect(event.winnerPlayerId, event.standings.first.playerId);
    }

    final afterSkills = container.read(currentFranchiseProvider).value!;
    expect(afterSkills.skillsCompetitionResults, hasLength(1));
    expect(
      nextGameDayTypes(
        afterSkills.seasonProgress,
      ).contains(GameType.allStarGame),
      isTrue,
    );

    // Every honoree really did land a real Achievement.allStarSelection
    // (2026-08-21, a direct GM ask: "will Awards include all-star
    // selections... it should, if it doesn't"), and every event's real
    // winner landed a real Achievement.skillsChallengeWinner.
    final everyPlayerAfterSkills = [
      ...afterSkills.roster.map((m) => m.player),
      for (final aiTeam in afterSkills.league.aiTeams)
        ...aiTeam.roster.map((m) => m.player),
    ];
    Player playerById(String id) =>
        everyPlayerAfterSkills.firstWhere((p) => p.id == id);
    for (final honoreeId in {
      ...skillsResult.squads[Conference.atlantic]!,
      ...skillsResult.squads[Conference.pacific]!,
    }) {
      expect(
        playerById(honoreeId).achievements.any(
          (a) => a.achievement == Achievement.allStarSelection,
        ),
        isTrue,
        reason: 'honoree $honoreeId should have Achievement.allStarSelection',
      );
    }
    for (final event in skillsResult.events) {
      expect(
        playerById(event.winnerPlayerId).achievements.any(
          (a) => a.achievement == Achievement.skillsChallengeWinner,
        ),
        isTrue,
        reason:
            '${event.event} winner ${event.winnerPlayerId} should have '
            'Achievement.skillsChallengeWinner',
      );
    }

    final gameAdvance = await container
        .read(currentFranchiseProvider.notifier)
        .advanceAllStarGameDay();

    expect(gameAdvance, isNotNull);
    expect(gameAdvance!.result.game.type, GameType.allStarGame);
    expect(gameAdvance.result.match.homeScore, isNot(0));

    final honoreeIds = {
      ...skillsResult.squads[Conference.atlantic]!,
      ...skillsResult.squads[Conference.pacific]!,
    };
    expect(honoreeIds, contains(gameAdvance.mvpPlayerId));

    // The MVP's real achievement/nickname landed somewhere in the
    // league -- either the GM's own roster or one of the 19 AI teams.
    final afterGame = container.read(currentFranchiseProvider).value!;
    final everyPlayer = [
      ...afterGame.roster.map((m) => m.player),
      for (final aiTeam in afterGame.league.aiTeams)
        ...aiTeam.roster.map((m) => m.player),
    ];
    final mvp = everyPlayer.firstWhere((p) => p.id == gameAdvance.mvpPlayerId);
    expect(
      mvp.achievements.any((a) => a.achievement == Achievement.allStarMvp),
      isTrue,
    );
    expect(mvp.nickname, isNotNull);

    // The season keeps advancing normally afterward, straight through
    // to the postseason -- the All-Star break doesn't derail anything.
    progress = afterGame.seasonProgress;
    guard = 0;
    while (!progress.isComplete && guard < 60) {
      await container.read(currentFranchiseProvider.notifier).advanceGameDay();
      progress = container.read(currentFranchiseProvider).value!.seasonProgress;
      guard++;
    }
    expect(progress.isComplete, isTrue);
  });
}
