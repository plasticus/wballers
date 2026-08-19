import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/draft/generation/draft_generator.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/season/application/franchise_rosters.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_transition_advancer.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

/// Plays [franchise] all the way through its postseason via the real
/// provider (same "play out a whole season" pattern
/// `current_franchise_provider_test.dart` already established), and
/// returns the resulting persisted [Franchise] -- `seasonIsOver` true,
/// ready for [beginNextSeason].
Future<Franchise> _playedOutFranchise(Franchise franchise) async {
  final container = ProviderContainer(
    overrides: [
      saveRepositoryProvider.overrideWithValue(InMemorySaveRepository()),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(currentFranchiseProvider.notifier)
      .createFranchise(franchise);

  var progress = franchise.seasonProgress;
  var guard = 0;
  while (!progress.isComplete && guard < 60) {
    await container.read(currentFranchiseProvider.notifier).advanceGameDay();
    progress = container.read(currentFranchiseProvider).value!.seasonProgress;
    guard++;
  }
  await container
      .read(currentFranchiseProvider.notifier)
      .simulatePostseasonAndPersist();
  return container.read(currentFranchiseProvider).value!;
}

void main() {
  test(
    'beginNextSeason increments season, resets progress/training/mail-source '
    'history, and leaves the roster untouched (0D_Season_2_Roadmap.md, '
    'Foundation)',
    () async {
      final base = withFullActiveRoster(
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
      final playedOut = await _playedOutFranchise(base);
      expect(seasonIsOver(playedOut), isTrue);

      final next = beginNextSeason(playedOut);

      expect(next.season, 1);
      expect(next.seasonProgress.playedGames, isEmpty);
      expect(next.seasonProgress.nextGameDayIndex, 0);
      expect(next.seasonProgress.isComplete, isFalse);
      expect(next.nextTrainingWeek, 1);
      expect(next.trainingReports, isEmpty);
      expect(next.seasonEndAgingResults, isEmpty);
      expect(next.skillsCompetitionResults, isEmpty);
      // Foundation-only scope: no aging/roster changes yet.
      expect(
        next.roster.map((m) => m.player.id),
        playedOut.roster.map((m) => m.player.id),
      );
    },
  );

  test('is deterministic for the same played-out franchise', () async {
    final base = withFullActiveRoster(
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
    final playedOut = await _playedOutFranchise(base);

    final a = beginNextSeason(playedOut);
    final b = beginNextSeason(playedOut);

    expect(
      a.seasonProgress.schedule.games.length,
      b.seasonProgress.schedule.games.length,
    );
    for (var i = 0; i < a.seasonProgress.schedule.games.length; i++) {
      expect(
        a.seasonProgress.schedule.games[i].homeTeamAbbreviation,
        b.seasonProgress.schedule.games[i].homeTeamAbbreviation,
      );
      expect(
        a.seasonProgress.schedule.games[i].awayTeamAbbreviation,
        b.seasonProgress.schedule.games[i].awayTeamAbbreviation,
      );
    }
  });

  test(
    'the new season\'s schedule is a genuinely different roll, not a replay '
    'of season 0\'s (the whole point of folding season into the seed)',
    () async {
      final base = withFullActiveRoster(
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
      final playedOut = await _playedOutFranchise(base);
      final next = beginNextSeason(playedOut);

      final season0Schedule = generateSeasonSchedule(
        allLeagueTeams(playedOut),
        Random(playedOut.simulationSeed + kSeasonScheduleSeedOffset),
      );

      // Same preseason pairing order would mean season folding silently
      // did nothing -- assert the two schedules actually diverge.
      final season0Preseason = season0Schedule.games
          .where((g) => g.week == kPreseasonWeek)
          .map((g) => '${g.homeTeamAbbreviation}-${g.awayTeamAbbreviation}')
          .toList();
      final season1Preseason = next.seasonProgress.schedule.games
          .where((g) => g.week == kPreseasonWeek)
          .map((g) => '${g.homeTeamAbbreviation}-${g.awayTeamAbbreviation}')
          .toList();
      expect(season1Preseason, isNot(equals(season0Preseason)));
    },
  );

  test('appends a fresh batch of free agents to whatever was already unsigned '
      '-- nothing existing gets discarded (2026-08-11, 0D_Season_2_Roadmap.md: '
      'Player pool refresh)', () async {
    final base = withFullActiveRoster(
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
    final playedOut = await _playedOutFranchise(base);
    final oldFreeAgentIds = playedOut.freeAgents.map((p) => p.id).toSet();

    final next = beginNextSeason(playedOut);

    expect(next.freeAgents.length, greaterThan(playedOut.freeAgents.length));
    expect(
      next.freeAgents.map((p) => p.id).toSet(),
      containsAll(oldFreeAgentIds),
    );
  });

  test('replaces the entire draft class with a fresh one -- real, persisted '
      'prospects, not a re-derived preview (2026-08-11, '
      '0D_Season_2_Roadmap.md: Player pool refresh)', () async {
    final base = withFullActiveRoster(
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
    final playedOut = await _playedOutFranchise(base);
    expect(playedOut.draftClass, isEmpty); // nothing persisted pre-season-1

    final next = beginNextSeason(playedOut);

    expect(next.draftClass, hasLength(kDefaultDraftClassSize));
  });

  test('sets up a fresh draftInProgress, ordered by the just-finished '
      'season\'s final standings (2026-08-11, 0D_Season_2_Roadmap.md: The '
      'draft, for real)', () async {
    final base = withFullActiveRoster(
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
    final playedOut = await _playedOutFranchise(base);
    expect(playedOut.draftInProgress, isNull);

    final next = beginNextSeason(playedOut);

    expect(next.draftInProgress, isNotNull);
    expect(next.draftInProgress!.picks, isEmpty);
    expect(next.draftInProgress!.rounds, kDraftRounds);
    expect(
      next.draftInProgress!.order.toSet(),
      allLeagueTeams(playedOut).map((t) => t.abbreviation).toSet(),
    );
  });

  test('bakes only the draft now starting\'s slice of pickOwnershipOverrides '
      'into the fresh draftInProgress, and carries any further-out season '
      'forward untouched rather than resetting (2026-08-19, real '
      'draft-pick ownership, multi-season future picks)', () async {
    final base = withFullActiveRoster(
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
    final aiAbbreviation = base.league.aiTeams.first.team.abbreviation;
    // base.season is 0 -- beginNextSeason is about to start season 1's
    // draft, so that's the slice that should get baked in and removed.
    // Season 2's pick is one more season out still -- it should carry
    // forward into the live field untouched.
    final tradedThisDraft = {
      2: {base.team.abbreviation: aiAbbreviation},
    };
    final tradedNextDraftOut = {
      1: {aiAbbreviation: base.team.abbreviation},
    };
    final withTrades = base.copyWithPickOwnershipOverrides({
      1: tradedThisDraft,
      2: tradedNextDraftOut,
    });
    final playedOut = await _playedOutFranchise(withTrades);
    expect(playedOut.pickOwnershipOverrides, {
      1: tradedThisDraft,
      2: tradedNextDraftOut,
    });

    final next = beginNextSeason(playedOut);

    // Season 1's slice (this draft) got baked into the frozen
    // DraftInProgress snapshot.
    expect(next.draftInProgress!.pickOwnershipOverrides, tradedThisDraft);
    // Season 2's slice (still one more out) carries forward live,
    // untouched -- not reset, and season 1's entry is gone (spent).
    expect(next.pickOwnershipOverrides, {2: tradedNextDraftOut});
  });

  test('draftInProgress order is deterministic for the same played-out '
      'franchise', () async {
    final base = withFullActiveRoster(
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
    final playedOut = await _playedOutFranchise(base);

    final a = beginNextSeason(playedOut);
    final b = beginNextSeason(playedOut);

    expect(a.draftInProgress!.order, b.draftInProgress!.order);
  });

  test('snapshots every current player\'s overall into '
      'seasonStartOverallByPlayerId, own roster and every AI team '
      '(2026-08-11, 0D_Season_2_Roadmap.md: Presentation -- Most Improved '
      'Player support)', () async {
    final base = withFullActiveRoster(
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
    final playedOut = await _playedOutFranchise(base);
    expect(playedOut.seasonStartOverallByPlayerId, isEmpty);

    final next = beginNextSeason(playedOut);

    for (final membership in next.roster) {
      expect(
        next.seasonStartOverallByPlayerId[membership.player.id],
        membership.player.ratings.overall,
      );
    }
    for (final aiTeam in next.league.aiTeams) {
      for (final membership in aiTeam.roster) {
        expect(
          next.seasonStartOverallByPlayerId[membership.player.id],
          membership.player.ratings.overall,
        );
      }
    }
  });

  test('asserts when the season isn\'t actually over yet', () async {
    final base = withFullActiveRoster(
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

    expect(() => beginNextSeason(base), throwsA(isA<AssertionError>()));
  });
}
