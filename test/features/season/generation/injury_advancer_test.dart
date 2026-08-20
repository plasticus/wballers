import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/domain/injury_report_entry.dart';
import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/match/domain/match_result.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_injury.dart';
import 'package:womensbballmgr/features/roster/domain/roster_status.dart';
import 'package:womensbballmgr/features/season/domain/game_day.dart';
import 'package:womensbballmgr/features/season/domain/game_result.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/generation/injury_advancer.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/portrait_test_helpers.dart';

MatchResult _fakeMatchResult(Map<Player, double> minutesPlayed) {
  return MatchResult(
    homeScore: 80,
    awayScore: 70,
    homeScoreByQuarter: const [20, 20, 20, 20],
    awayScoreByQuarter: const [17, 17, 18, 18],
    events: const [],
    minutesPlayed: minutesPlayed,
    personalFouls: const {},
    fouledOut: const {},
    finalEnergy: const {},
  );
}

GameResult _gameResult({
  required String home,
  required String away,
  required Map<Player, double> minutesPlayed,
  int week = 1,
  GameDay day = GameDay.sunday,
}) {
  return GameResult(
    game: ScheduledGame(
      week: week,
      day: day,
      homeTeamAbbreviation: home,
      awayTeamAbbreviation: away,
      type: GameType.regularSeason,
    ),
    match: _fakeMatchResult(minutesPlayed),
  );
}

void main() {
  group('resolveInjuries -- recovery', () {
    test('the GM\'s own player, playing through it, ticks the countdown '
        'down by one game', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final target = franchise.roster.first;
      final injured = franchise.roster.indexOf(target);
      final withInjury = [...franchise.roster];
      withInjury[injured] = target.copyWith(
        injury: PlayerInjury.fresh(InjurySeverity.moderate),
      );
      final base = franchise.copyWithRoster(withInjury);
      final aiAbbreviation = base.league.aiTeams.first.team.abbreviation;

      final result = resolveInjuries(
        Random(1),
        base,
        gamesPlayed: [
          _gameResult(
            home: base.team.abbreviation,
            away: aiAbbreviation,
            minutesPlayed: {target.player: 20},
          ),
        ],
        isPostseason: false,
      );

      final updated = result.roster.firstWhere(
        (m) => m.player.id == target.player.id,
      );
      expect(updated.injury!.severity, InjurySeverity.moderate);
      expect(updated.injury!.gamesRemainingAtSeverity, 3);
      // Playing through it doesn't get benched -- still active.
      expect(updated.status, RosterStatus.active);
    });

    test('the GM\'s own player, benched (0 minutes), drops a full tier '
        'instantly regardless of games remaining', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final target = franchise.roster.first;
      final injured = franchise.roster.indexOf(target);
      final withInjury = [...franchise.roster];
      withInjury[injured] = target.copyWith(
        status: RosterStatus.reserveInactive,
        injury: PlayerInjury.fresh(InjurySeverity.major),
      );
      final base = franchise.copyWithRoster(withInjury);
      final aiAbbreviation = base.league.aiTeams.first.team.abbreviation;

      final result = resolveInjuries(
        Random(1),
        base,
        gamesPlayed: [
          _gameResult(
            home: base.team.abbreviation,
            away: aiAbbreviation,
            // No minutes at all for the injured player -- she's in
            // Reserve/Inactive, not on the active roster passed to the
            // match engine in a real call, but the resolver only needs
            // her *absence* from minutesPlayed to read this as "benched".
            minutesPlayed: const {},
          ),
        ],
        isPostseason: false,
      );

      final updated = result.roster.firstWhere(
        (m) => m.player.id == target.player.id,
      );
      expect(updated.injury!.severity, InjurySeverity.moderate);
      expect(updated.injury!.gamesRemainingAtSeverity, 4);
      // The GM's own team is never auto-reactivated -- still parked.
      expect(updated.status, RosterStatus.reserveInactive);
    });

    test('the GM\'s own player fully heals while parked in Reserve/'
        'Inactive -- stays parked, but recoveredWhileReserved flips true', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final target = franchise.roster.first;
      final injured = franchise.roster.indexOf(target);
      final withInjury = [...franchise.roster];
      withInjury[injured] = target.copyWith(
        status: RosterStatus.reserveInactive,
        injury: PlayerInjury.fresh(InjurySeverity.minor),
      );
      final base = franchise.copyWithRoster(withInjury);
      final aiAbbreviation = base.league.aiTeams.first.team.abbreviation;

      final result = resolveInjuries(
        Random(1),
        base,
        gamesPlayed: [
          _gameResult(
            home: base.team.abbreviation,
            away: aiAbbreviation,
            minutesPlayed: const {},
          ),
        ],
        isPostseason: false,
      );

      final updated = result.roster.firstWhere(
        (m) => m.player.id == target.player.id,
      );
      expect(updated.injury, isNull);
      expect(updated.status, RosterStatus.reserveInactive);
      expect(updated.recoveredWhileReserved, isTrue);
    });

    test('an AI team\'s player fully heals while parked in Reserve/'
        'Inactive -- automatically reactivated to active', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final aiTeam = franchise.league.aiTeams.first;
      final target = aiTeam.roster.first;
      final index = aiTeam.roster.indexOf(target);
      final newAiRoster = [...aiTeam.roster];
      newAiRoster[index] = target.copyWith(
        status: RosterStatus.reserveInactive,
        injury: PlayerInjury.fresh(InjurySeverity.minor),
      );
      final base = franchise.copyWithLeague(
        League(
          aiTeams: [
            for (final t in franchise.league.aiTeams)
              if (t.team.abbreviation == aiTeam.team.abbreviation)
                t.copyWithRoster(newAiRoster)
              else
                t,
          ],
        ),
      );

      final result = resolveInjuries(
        Random(1),
        base,
        gamesPlayed: [
          _gameResult(
            home: base.team.abbreviation,
            away: aiTeam.team.abbreviation,
            minutesPlayed: const {},
          ),
        ],
        isPostseason: false,
      );

      final updatedAiTeam = result.league.aiTeams.firstWhere(
        (t) => t.team.abbreviation == aiTeam.team.abbreviation,
      );
      final updated = updatedAiTeam.roster.firstWhere(
        (m) => m.player.id == target.player.id,
      );
      expect(updated.injury, isNull);
      expect(updated.status, RosterStatus.active);
      // Only the GM's own roster ever sets the reminder flag.
      expect(updated.recoveredWhileReserved, isFalse);
    });
  });

  group('resolveInjuries -- new injuries', () {
    test('never rolls a new injury for a player who logged no real '
        'minutes', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final aiAbbreviation = franchise.league.aiTeams.first.team.abbreviation;

      // A very forgiving 500-trial sweep with a guaranteed-large chance
      // (every player "logged 0 minutes") -- if the eligibility check
      // were broken (rolling for everyone regardless of minutes), this
      // would reliably produce at least one entry.
      for (var seed = 0; seed < 500; seed++) {
        final result = resolveInjuries(
          Random(seed),
          franchise,
          gamesPlayed: [
            _gameResult(
              home: franchise.team.abbreviation,
              away: aiAbbreviation,
              minutesPlayed: const {}, // nobody logged minutes
            ),
          ],
          isPostseason: false,
        );
        expect(result.injuryReports, isEmpty, reason: 'seed $seed');
      }
    });

    test('rolls new injuries for players who did log real minutes, over '
        'enough trials', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final aiAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
      final minutesPlayed = {for (final m in franchise.roster) m.player: 30.0};

      var sawAnInjury = false;
      for (var seed = 0; seed < 200; seed++) {
        final result = resolveInjuries(
          Random(seed),
          franchise,
          gamesPlayed: [
            _gameResult(
              home: franchise.team.abbreviation,
              away: aiAbbreviation,
              minutesPlayed: minutesPlayed,
            ),
          ],
          isPostseason: false,
        );
        if (result.injuryReports.isNotEmpty) {
          sawAnInjury = true;
          break;
        }
      }
      expect(sawAnInjury, isTrue);
    });

    test('an AI team\'s newly-injured player gets auto-benched to '
        'Reserve/Inactive when a slot is open', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final aiTeam = franchise.league.aiTeams.first;
      final minutesPlayed = {for (final m in aiTeam.roster) m.player: 30.0};

      // Find a seed that actually produces a new AI injury within a
      // reasonable number of tries, then check the auto-bench behavior on
      // it specifically.
      for (var seed = 0; seed < 500; seed++) {
        final result = resolveInjuries(
          Random(seed),
          franchise,
          gamesPlayed: [
            _gameResult(
              home: franchise.team.abbreviation,
              away: aiTeam.team.abbreviation,
              minutesPlayed: minutesPlayed,
            ),
          ],
          isPostseason: false,
        );
        final aiEntries = result.injuryReports.where(
          (e) => e.teamAbbreviation == aiTeam.team.abbreviation,
        );
        if (aiEntries.isEmpty) continue;

        final updatedAiTeam = result.league.aiTeams.firstWhere(
          (t) => t.team.abbreviation == aiTeam.team.abbreviation,
        );
        final injuredMembership = updatedAiTeam.roster.firstWhere(
          (m) => m.player.id == aiEntries.first.playerId,
        );
        expect(injuredMembership.injury, isNotNull);
        expect(injuredMembership.status, RosterStatus.reserveInactive);
        return;
      }
      fail('expected at least one AI injury within 500 seeds');
    });
  });

  group('resolveInjuries -- housekeeping', () {
    test('is a no-op when gamesPlayed is empty', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());

      final result = resolveInjuries(
        Random(1),
        franchise,
        gamesPlayed: const [],
        isPostseason: false,
      );

      expect(identical(result, franchise), isTrue);
    });

    test('appends to injuryReports rather than replacing it', () {
      final franchise = withFullActiveRoster(franchiseForPortraitTests());
      final aiAbbreviation = franchise.league.aiTeams.first.team.abbreviation;
      final withExisting = franchise.copyWithInjuryReports(const [
        InjuryReportEntry(
          playerId: 'someone-else',
          name: 'Someone Else',
          teamAbbreviation: 'ZZZ',
          severity: InjurySeverity.minor,
          week: 1,
          day: GameDay.sunday,
          season: 0,
        ),
      ]);

      final result = resolveInjuries(
        Random(1),
        withExisting,
        gamesPlayed: [
          _gameResult(
            home: franchise.team.abbreviation,
            away: aiAbbreviation,
            minutesPlayed: const {},
          ),
        ],
        isPostseason: false,
      );

      expect(result.injuryReports.first.playerId, 'someone-else');
    });
  });
}
