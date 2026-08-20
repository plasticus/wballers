import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../franchise/domain/injury_report_entry.dart';
import '../../league/domain/league.dart';
import '../../player/domain/player.dart';
import '../../player/domain/player_injury.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/roster_status.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_day.dart';
import '../domain/game_result.dart';

/// Seed offset for [resolveInjuries]' [Random] stream -- next free number
/// after `coach_aging_advancer.dart`'s `kCoachAgingSeedOffset` (24).
/// Combined with [SeasonProgress.nextGameDayIndex] for a per-game-day call
/// (`advanceGameDay`/`advanceGameDayWithOwnResult`), or used bare for the
/// once-per-postseason call (`simulatePostseasonAndPersist`) -- same two
/// conventions every other seed offset in this codebase already follows.
const kInjuryResolutionSeedOffset = 25;

/// Resolves injury risk, recovery, and AI auto-bench/reactivate across
/// every team [gamesPlayed] touches, and returns the updated [franchise]
/// -- new injuries suffered, existing injuries advanced (bench-driven
/// recovery or the ordinary played-through-it countdown), and
/// [Franchise.injuryReports] appended with anything new
/// (2026-08-20, following the injuries design pass).
///
/// [gamesPlayed] must already be in the real chronological order they
/// were played -- both [advanceGameDay] (a single day's results) and
/// [simulatePostseason] (many days' worth, across a whole bracket) already
/// produce their own results in that order, so callers can pass either
/// straight through. Processes each game's 2 teams once each; a team with
/// no game that day (a bye) is a known, deliberate simplification left
/// out entirely -- `0B_Planned.md`'s own design note treats a bye day the
/// same as being benched, but that needs a full team-calendar-day model
/// this doesn't have yet, so an injured player parked on a bye-week team
/// simply doesn't advance their recovery that day rather than crashing or
/// silently guessing.
///
/// A game whose home/away abbreviation isn't a real team in
/// [rosterMembershipsByAbbreviation] (the All-Star Game's synthetic
/// conference squads) is skipped outright -- no injury risk in an
/// exhibition game.
Franchise resolveInjuries(
  Random random,
  Franchise franchise, {
  required List<GameResult> gamesPlayed,
  required bool isPostseason,
}) {
  if (gamesPlayed.isEmpty) return franchise;

  final working = <String, List<RosterMembership>>{
    ...rosterMembershipsByAbbreviation(franchise),
  };
  final newReports = <InjuryReportEntry>[];

  for (final result in gamesPlayed) {
    final homeAbbreviation = result.game.homeTeamAbbreviation;
    final awayAbbreviation = result.game.awayTeamAbbreviation;
    if (!working.containsKey(homeAbbreviation) ||
        !working.containsKey(awayAbbreviation)) {
      continue;
    }

    for (final abbreviation in [homeAbbreviation, awayAbbreviation]) {
      final (updated, entries) = _processTeamForGame(
        random: random,
        roster: working[abbreviation]!,
        teamAbbreviation: abbreviation,
        isOwnTeam: abbreviation == franchise.team.abbreviation,
        minutesPlayed: result.match.minutesPlayed,
        week: result.game.week,
        day: result.game.day,
        season: franchise.season,
        isPostseason: isPostseason,
      );
      working[abbreviation] = updated;
      newReports.addAll(entries);
    }
  }

  final newAiTeams = [
    for (final aiTeam in franchise.league.aiTeams)
      aiTeam.copyWithRoster(working[aiTeam.team.abbreviation]!),
  ];

  return franchise
      .copyWithRoster(working[franchise.team.abbreviation]!)
      .copyWithLeague(League(aiTeams: newAiTeams))
      .copyWithInjuryReports(newReports);
}

/// One team's roster, advanced by exactly one of their own games --
/// existing injuries recovered or countdown-ticked, a fresh injury rolled
/// for anyone eligible, and (AI teams only) automatically benched to/
/// reactivated from [RosterStatus.reserveInactive].
///
/// [isOwnTeam] is the GM's own club -- never auto-benched/reactivated (a
/// direct GM ask: "we don't need a new toggle... the AI teams should
/// absolutely, always bench injured players... via the reserve slots" --
/// implicitly, *not* the GM's own team, who keeps the existing manual
/// `moveRosterStatus` lever instead). A GM-side player whose injury clears
/// while parked in [RosterStatus.reserveInactive] gets
/// [RosterMembership.recoveredWhileReserved] set instead of an automatic
/// reactivation, so [InjuryRecoveredMailItem] can remind the GM to
/// actually make that call.
(List<RosterMembership>, List<InjuryReportEntry>) _processTeamForGame({
  required Random random,
  required List<RosterMembership> roster,
  required String teamAbbreviation,
  required bool isOwnTeam,
  required Map<Player, double> minutesPlayed,
  required int week,
  required GameDay day,
  required int season,
  required bool isPostseason,
}) {
  final entries = <InjuryReportEntry>[];
  final updated = <RosterMembership>[];
  var reserveInactiveCount = roster
      .where((m) => m.status == RosterStatus.reserveInactive)
      .length;

  for (final membership in roster) {
    final isActiveToday = membership.status == RosterStatus.active;
    final minutes = minutesPlayed[membership.player] ?? 0;
    final playedRealMinutes = isActiveToday && minutes > 0;

    final currentInjury = membership.injury;
    if (currentInjury != null) {
      final nextInjury = currentInjury.recoverAfterGame(
        playedRealMinutes: playedRealMinutes,
      );
      if (nextInjury != null) {
        updated.add(membership.copyWith(injury: nextInjury));
        continue;
      }
      // Fully healed this game.
      if (!isOwnTeam && membership.status == RosterStatus.reserveInactive) {
        reserveInactiveCount--;
        updated.add(
          membership.copyWith(injury: null, status: RosterStatus.active),
        );
        continue;
      }
      updated.add(
        membership.copyWith(
          injury: null,
          recoveredWhileReserved:
              isOwnTeam && membership.status == RosterStatus.reserveInactive,
        ),
      );
      continue;
    }

    // Healthy -- only eligible for a fresh injury roll if they actually
    // logged real minutes today.
    if (playedRealMinutes) {
      final chance = injuryChanceFor(
        traits: membership.player.traits,
        isPostseason: isPostseason,
      );
      if (random.nextDouble() < chance) {
        final severity = rollInjurySeverity(random, membership.player.traits);
        entries.add(
          InjuryReportEntry(
            playerId: membership.player.id,
            name: membership.player.name,
            teamAbbreviation: teamAbbreviation,
            severity: severity,
            week: week,
            day: day,
            season: season,
          ),
        );
        final freshInjury = PlayerInjury.fresh(severity);
        if (!isOwnTeam && reserveInactiveCount < kMaxInactiveRosterSpots) {
          reserveInactiveCount++;
          updated.add(
            membership.copyWith(
              injury: freshInjury,
              status: RosterStatus.reserveInactive,
            ),
          );
        } else {
          updated.add(membership.copyWith(injury: freshInjury));
        }
        continue;
      }
    }
    updated.add(membership);
  }

  return (updated, entries);
}

/// Every active roster player's current injury rating penalty
/// (`player_injury.dart`'s `injuryBonusFor`), keyed by [Player] -- what
/// `match_engine.dart`'s `injuryPenalty` param needs ahead of simulating
/// [roster]'s next game. Players with no current injury simply don't
/// appear in the map (same "opt-in only" posture the fatigue `energy` map
/// already has).
Map<Player, double> injuryPenaltyFor(List<RosterMembership> roster) {
  return {
    for (final membership in roster)
      if (membership.injury != null)
        membership.player: injuryBonusFor(membership.injury),
  };
}
