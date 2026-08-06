import '../../coach/domain/coach.dart';
import '../../league/domain/initial_league.dart';
import '../../league/domain/league.dart';
import '../../league/domain/team.dart';
import '../../roster/domain/roster_membership.dart';
import '../../roster/domain/starting_lineup.dart';
import '../../season/domain/season_progress.dart';
import '../../training/domain/training_coach.dart';
import '../../training/domain/training_plan.dart';
import '../../training/domain/training_report.dart';

/// The player's save-game: their General Manager persona, their club, its
/// hired coach, its roster, and its starting lineup. This is the save-game
/// root — `franchise_json.dart` is what actually goes through
/// `SaveEnvelope`/`SaveRepository`.
///
/// The player is the GM, not [coach] — see the note on [Coach]. [team] is
/// the club's own identity (name/colors/city), chosen at onboarding — not
/// a reference into `kLeagueTeamPool`. [simulationSeed] also determines
/// which 20 of the pool's 40 candidate teams actually exist in this
/// playthrough's league (`drawLeagueTeams`, `league_draw.dart`). Which of
/// those 20 this franchise replaced is captured separately, in
/// [replacedTeamAbbreviation] -- picked at onboarding, defaulting to a
/// random team in the chosen conference but GM-overridable. `LeagueScreen`
/// uses it to substitute [team] in for the replaced original in the league
/// listing, so the displayed league genuinely reads as 19 AI teams + 1 GM
/// team. [league] is those 19 AI teams' real generated rosters
/// (`generateLeague`) -- a real league runtime, not just identities.
///
/// Roster legality isn't enforced here — see `evaluateFranchiseLegality`.
/// Lineup legality isn't enforced here either — see `evaluateLineupLegality`.
class Franchise {
  Franchise({
    required this.id,
    required this.gmName,
    required this.team,
    required this.coach,
    required this.roster,
    required this.startingLineup,
    required this.simulationSeed,
    required this.replacedTeamAbbreviation,
    required this.league,
    required this.seasonProgress,
    required this.trainingCoaches,
    required this.trainingPlan,
    required this.nextTrainingWeek,
    this.trainingReports = const [],
  }) : assert(
         _replacedTeamIsInSameConference(team, replacedTeamAbbreviation),
         'replacedTeamAbbreviation must be one of the league team pool, '
         'in the same conference as team',
       ),
       assert(
         !league.aiTeams.any(
           (aiTeam) => aiTeam.team.abbreviation == replacedTeamAbbreviation,
         ),
         'league.aiTeams must not include the team the GM replaced',
       ),
       assert(trainingCoaches.length == 3, 'always exactly 3 training coaches');

  /// Stable identifier for this save, independent of [team]'s name (which
  /// the GM could rebrand later).
  final String id;

  /// The player's own name — they're the General Manager, not [coach].
  final String gmName;

  final Team team;
  final Coach coach;
  final List<RosterMembership> roster;
  final StartingLineup startingLineup;

  /// Seeds every deterministic random source this franchise's simulation
  /// uses — same seed plus same saved state must reproduce the same
  /// results.
  final int simulationSeed;

  /// The `kLeagueTeamPool` abbreviation this franchise replaced.
  /// Bookkeeping only for now -- see the class doc comment.
  final String replacedTeamAbbreviation;

  /// The other 19 teams in this playthrough's league, with real generated
  /// rosters -- see the class doc comment and `generateLeague`.
  final League league;

  /// This franchise's season: the full schedule, every game played so
  /// far, and which week comes next (`generateSeasonSchedule`,
  /// `advanceOneWeek`). Generated once at franchise creation, same as
  /// [league].
  final SeasonProgress seasonProgress;

  /// This franchise's 3 individual-development staff (`training_coach.dart`),
  /// generated once at franchise creation same as [coach] -- no hire/fire
  /// flow yet, same posture as the head coach.
  final List<TrainingCoach> trainingCoaches;

  /// The GM's current training instructions -- sticky (reused week to
  /// week until changed), edited via the Training screen.
  final TrainingPlan trainingPlan;

  /// The next schedule week eligible for training resolution -- the
  /// training-cadence equivalent of `SeasonProgress.nextGameDayIndex`,
  /// but its own pointer since training resolves on its own weekly
  /// rhythm, not per game day (`lastFullyCompletedWeek`,
  /// `training_advancer.dart`).
  final int nextTrainingWeek;

  /// Every training report so far this season -- the surfaced-moment
  /// history the (not yet built) News feed will eventually list; kept
  /// here in the meantime as the only place a past report can be found
  /// again. Lean by construction (`TrainingReport` only records players
  /// who actually changed), so keeping the whole season's worth doesn't
  /// meaningfully grow the save.
  final List<TrainingReport> trainingReports;

  /// Returns a copy with [startingLineup] replaced -- the only field the
  /// lineup editor needs to change.
  Franchise copyWithLineup(StartingLineup newLineup) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: roster,
      startingLineup: newLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
    );
  }

  /// Returns a copy with [newCoach] replacing [coach] -- the portrait
  /// editor's coach-appearance path.
  Franchise copyWithCoach(Coach newCoach) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: newCoach,
      roster: roster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
    );
  }

  /// Returns a copy with [newRoster] replacing [roster] -- the portrait
  /// editor's player-appearance path.
  Franchise copyWithRoster(List<RosterMembership> newRoster) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: newRoster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
    );
  }

  /// Returns a copy with [newSeasonProgress] replacing [seasonProgress] --
  /// `advanceOneWeek`'s result gets threaded back in through this.
  Franchise copyWithSeasonProgress(SeasonProgress newSeasonProgress) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: roster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: newSeasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
    );
  }

  /// Returns a copy with [newTrainingPlan] replacing [trainingPlan] -- the
  /// Training screen's only write path.
  Franchise copyWithTrainingPlan(TrainingPlan newTrainingPlan) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: roster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: newTrainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
    );
  }

  /// Returns a copy reflecting one training cycle having resolved:
  /// [newRoster] carries whatever rating changes it produced,
  /// [newNextTrainingWeek] advances the training pointer, and [newReport]
  /// joins [trainingReports]' history. Bundled into one method (rather
  /// than three separate `copyWithX` calls) because these three always
  /// change together -- `training_advancer.dart`'s `runTraining` produces
  /// all three from a single resolution, and nothing else ever changes
  /// just one of them.
  Franchise copyWithTrainingResult({
    required List<RosterMembership> newRoster,
    required int newNextTrainingWeek,
    required TrainingReport newReport,
  }) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: newRoster,
      startingLineup: startingLineup,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: newNextTrainingWeek,
      trainingReports: [...trainingReports, newReport],
    );
  }
}

bool _replacedTeamIsInSameConference(
  Team team,
  String replacedTeamAbbreviation,
) {
  return kLeagueTeamPool.any(
    (t) =>
        t.abbreviation == replacedTeamAbbreviation &&
        t.conference == team.conference,
  );
}
