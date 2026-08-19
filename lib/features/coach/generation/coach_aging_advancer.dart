import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/ai_team_roster.dart';
import '../../league/domain/league.dart';
import '../domain/coach_lifecycle.dart';
import 'coach_generator.dart';

/// Seed offset for [resolveCoachAging]'s own `Random` stream -- next free
/// number after `ai_offseason_trade_advancer.dart`'s
/// `kAiOffseasonTradeSeedOffset` (23). Only ever actually consumed when a
/// coach's mandatory retirement fires (a fresh replacement needs a real
/// roll) -- most off-seasons, most coaches, this draws nothing at all.
const kCoachAgingSeedOffset = 24;

/// The result of one off-season's coach aging/mandatory-retirement pass.
class CoachAgingAdvance {
  const CoachAgingAdvance({
    required this.franchise,
    required this.ownCoachRetired,
    required this.retiredAiTeamAbbreviations,
  });

  final Franchise franchise;

  /// Whether the GM's own head coach hit mandatory retirement this call
  /// and was auto-replaced. Nothing surfaces this to the GM yet (no mail
  /// item exists for it, same "return the data, nothing displays it yet"
  /// posture `RosterLegalityAdvance.waivedPlayerIds`/
  /// `CoachFreeAgencyAdvance.firedTeamAbbreviations` already have) --
  /// visible in practice via the coach's own name changing wherever it's
  /// shown (`team_roster_screen.dart`'s `_CoachRow`,
  /// `AvailableHeadCoachesScreen`).
  final bool ownCoachRetired;

  /// Every AI team whose coach hit mandatory retirement this call --
  /// same "empty most off-seasons" shape every other season-end advance
  /// result already has.
  final Set<String> retiredAiTeamAbbreviations;
}

/// Resolves one off-season's worth of coach aging for every currently
/// employed coach (the GM's own and all 19 AI teams' -- there's no
/// "vacant coach" state, so this always has exactly 20 coaches to grow):
/// age +1, every `CoachStats` field +1 (`coach_generator.dart`'s
/// `growCoach`) -- "a flat +1 per skill every off-season," a direct GM
/// call (2026-08-19, `coach-lifecycle-notes.md`). Then checks mandatory
/// retirement (`coachHasReachedMandatoryRetirement`, age 66) against the
/// *grown* age -- a coach plays out their full 65-year-old season first,
/// same "one final season, then gone" shape players' own mandatory
/// retirement already has.
///
/// A retiring AI coach is replaced atomically, same "no separate vacancy
/// state" posture `resolveCoachFreeAgency` already established for
/// performance-based firing -- and resets [AiTeamRoster.coachHiredSeason]
/// to [Franchise.season] too, so the fresh hire gets the same real grace
/// period from `resolveCoachFreeAgency`'s own bottom-5 check (this
/// deliberately runs *before* that function, so a same-turn mandatory
/// retirement's replacement can never also get performance-fired the
/// same off-season). A retiring GM coach is also auto-replaced -- making
/// [Coach] genuinely optional (`Franchise.coach` nullable) purely to model
/// a brief "no coach" gap would ripple through every system that reads
/// it (match simulation, training, the in-game coaching picker) for a
/// gap nothing would ever actually observe, same reasoning
/// [AiTeamRoster] never models one either. The GM keeps full control
/// regardless -- `AvailableHeadCoachesScreen`'s hiring flow works
/// exactly the same whether their current coach is the one just
/// auto-assigned or one they hand-picked seasons ago.
///
/// Every replacement (GM or AI) is a fresh [kCoachEntryMinAge]-
/// [kCoachEntryMaxAge] hire, same age band every other real replacement
/// hire in the game uses -- only a team's very first-ever coach
/// (`league_generator.dart`, `expansion_franchise_factory.dart`) gets the
/// older, stronger [kCoachInitialLeagueMinAge]-[kCoachInitialLeagueMaxAge]
/// treatment.
CoachAgingAdvance resolveCoachAging(Random random, Franchise franchise) {
  final grownOwnCoach = growCoach(franchise.coach);
  final ownCoachRetired = coachHasReachedMandatoryRetirement(grownOwnCoach.age);
  final newOwnCoach = ownCoachRetired
      ? generateCoach(
          random,
          minAge: kCoachEntryMinAge,
          maxAge: kCoachEntryMaxAge,
        )
      : grownOwnCoach;

  final retiredAiTeamAbbreviations = <String>{};
  final newAiTeams = <AiTeamRoster>[];
  for (final aiTeam in franchise.league.aiTeams) {
    final grownCoach = growCoach(aiTeam.coach);
    if (coachHasReachedMandatoryRetirement(grownCoach.age)) {
      retiredAiTeamAbbreviations.add(aiTeam.team.abbreviation);
      newAiTeams.add(
        aiTeam.copyWithCoach(
          newCoach: generateCoach(
            random,
            minAge: kCoachEntryMinAge,
            maxAge: kCoachEntryMaxAge,
          ),
          hiredSeason: franchise.season,
        ),
      );
    } else {
      newAiTeams.add(
        aiTeam.copyWithCoach(
          newCoach: grownCoach,
          hiredSeason: aiTeam.coachHiredSeason,
        ),
      );
    }
  }

  return CoachAgingAdvance(
    franchise: franchise
        .copyWithCoach(newOwnCoach)
        .copyWithLeague(League(aiTeams: newAiTeams)),
    ownCoachRetired: ownCoachRetired,
    retiredAiTeamAbbreviations: retiredAiTeamAbbreviations,
  );
}
