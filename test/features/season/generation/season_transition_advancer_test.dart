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
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/domain/standings_entry.dart';
import 'package:womensbballmgr/features/season/generation/postseason_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';
import 'package:womensbballmgr/features/season/generation/season_transition_advancer.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

/// Plays [franchise] all the way through its postseason via the real
/// provider (same "play out a whole season" pattern
/// `current_franchise_provider_test.dart` already established), and
/// returns the resulting persisted [Franchise] -- `seasonIsOver` true,
/// ready for [beginNextSeason]. The postseason plays out through the exact
/// same `advanceGameDay` every other game day already uses (2026-08-20, a
/// direct GM report: "it needs to play all the games through the normal
/// system"), so a generous guard covers the whole season -- regular
/// season, Continental Cup, All-Star break, and the postseason bracket
/// through to a decided champion -- not just the regular season.
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
  while (!progress.isComplete && guard < 150) {
    await container.read(currentFranchiseProvider.notifier).advanceGameDay();
    progress = container.read(currentFranchiseProvider).value!.seasonProgress;
    guard++;
  }
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

  test(
    'beginNextSeason bumps the GM\'s own head coach\'s career record off '
    'the just-finished season\'s real standings/champion (2026-08-19, a '
    'direct GM ask: "Head coach needs a detail screen... career '
    'wins/losses, any trophies, how long they\'ve been a head coach")',
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
      final finalStandings = currentStandings(
        playedOut.seasonProgress,
        allLeagueTeams(playedOut),
      );
      final ownRecord = recordFor(playedOut.team.abbreviation, finalStandings);
      final wonChampionship =
          seasonChampion(playedOut.seasonProgress.playedGames) ==
          playedOut.team.abbreviation;

      final next = beginNextSeason(playedOut);

      expect(next.coach.seasonsAsHeadCoach, 1);
      expect(next.coach.careerWins, ownRecord.wins);
      expect(next.coach.careerLosses, ownRecord.losses);
      expect(next.coach.championshipsWon, wonChampionship ? 1 : 0);
      // Nothing else about the coach changed.
      expect(next.coach.name, playedOut.coach.name);
      expect(next.coach.stats, playedOut.coach.stats);
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

  test(
    'the new draftClass is promoted from upcomingDraftClass (rolled a '
    'season ahead), not freshly generated at the transition itself -- and '
    'a fresh upcomingDraftClass is rolled in turn for the season now '
    'starting (2026-08-21, a direct GM ask: "roll it at the start of the '
    'season instead of on draft day")',
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
      // Rolled at franchise creation already -- previewable from the very
      // first day of season 0, not just once season 1 actually begins.
      expect(base.upcomingDraftClass, hasLength(kDefaultDraftClassSize));

      final playedOut = await _playedOutFranchise(base);
      // Untouched all season -- the same stable class shown in the
      // Player Market's Draft tab the whole time.
      expect(
        playedOut.upcomingDraftClass.map((p) => p.player.id),
        base.upcomingDraftClass.map((p) => p.player.id),
      );

      final next = beginNextSeason(playedOut);

      // Promoted, not rerolled -- next.draftClass IS the exact class that
      // was already previewable all of last season.
      expect(
        next.draftClass.map((p) => p.player.id),
        playedOut.upcomingDraftClass.map((p) => p.player.id),
      );
      // A genuinely fresh class lined up for the season now starting --
      // different prospects than either the just-promoted draftClass or
      // last season's own upcomingDraftClass.
      expect(next.upcomingDraftClass, hasLength(kDefaultDraftClassSize));
      expect(
        next.upcomingDraftClass.map((p) => p.player.id),
        isNot(next.draftClass.map((p) => p.player.id)),
      );
    },
  );

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
