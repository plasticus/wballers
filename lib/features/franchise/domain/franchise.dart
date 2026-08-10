import '../../coach/domain/coach.dart';
import '../../league/domain/initial_league.dart';
import '../../league/domain/league.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import '../../season/domain/season_progress.dart';
import '../../training/domain/training_coach.dart';
import '../../training/domain/training_plan.dart';
import '../../training/domain/training_report.dart';

/// The player's save-game: their General Manager persona, their club, its
/// hired coach, and its roster. This is the save-game root —
/// `franchise_json.dart` is what actually goes through
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
/// There's no separate starting-lineup concept anymore: the top 5 players
/// in `roster`'s own active-roster order (the same order Bench Order
/// edits, and the same order `targetMinutesForOrderedRoster` reads) are
/// the starters, full stop -- a formerly-separate position-locked lineup
/// screen was dropped once it turned out to have no mechanical effect on
/// games at all, and no reason to force exactly one player per position
/// (a GM starting two point guards just means the second one effectively
/// plays as a shooting guard for the game, same as real basketball).
class Franchise {
  Franchise({
    required this.id,
    required this.gmName,
    required this.team,
    required this.coach,
    required this.roster,
    required this.simulationSeed,
    required this.replacedTeamAbbreviation,
    required this.league,
    required this.seasonProgress,
    required this.trainingCoaches,
    required this.trainingPlan,
    required this.nextTrainingWeek,
    this.trainingReports = const [],
    this.freeAgents = const [],
    this.readMailIds = const {},
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

  /// Every training report so far this season -- what `NewsScreen`
  /// (`news/presentation/news_screen.dart`) lists. Lean by construction
  /// (`TrainingReport` only records players who actually changed), so
  /// keeping the whole season's worth doesn't meaningfully grow the save.
  final List<TrainingReport> trainingReports;

  /// Unrostered players available to sign -- real, persisted game state
  /// (not to be confused with the Player Market screen's still-preview-only
  /// Trade Block/Draft tabs). Generated once at franchise creation
  /// (`generateFreeAgentPool`) and only ever shrinks as the GM signs
  /// players off it (`current_franchise_provider.dart`'s `signFreeAgent`)
  /// -- nothing ever adds to it after creation yet (a real free-agent
  /// market that refreshes over a season is future work). Defaults to
  /// empty for every pre-existing caller (mostly tests) that doesn't care
  /// about free agency, same pattern [trainingReports] already uses.
  final List<Player> freeAgents;

  /// Ids of every Mail inbox item (`mail/domain/mail_item.dart`'s
  /// `MailItem.id`) the GM has already opened -- the Mail tab's unread
  /// badge (`mail/application/mailbox.dart`'s `unreadMailCount`) is
  /// everything `mailboxFor` derives right now that isn't in this set.
  /// Mail items themselves are never persisted (they're re-derived fresh
  /// from live franchise state, same as `mailboxFor`'s doc comment
  /// explains) -- only which ones have been seen needs to survive a
  /// save/reload.
  final Set<String> readMailIds;

  /// Returns a copy with [newCoach] replacing [coach] -- the portrait
  /// editor's coach-appearance path.
  Franchise copyWithCoach(Coach newCoach) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: newCoach,
      roster: roster,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
      freeAgents: freeAgents,
      readMailIds: readMailIds,
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
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
      freeAgents: freeAgents,
      readMailIds: readMailIds,
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
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: newSeasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
      freeAgents: freeAgents,
      readMailIds: readMailIds,
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
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: newTrainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
      freeAgents: freeAgents,
      readMailIds: readMailIds,
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
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: newNextTrainingWeek,
      trainingReports: [...trainingReports, newReport],
      freeAgents: freeAgents,
      readMailIds: readMailIds,
    );
  }

  /// Returns a copy reflecting [roster]/[freeAgents] moving a player
  /// between them: [newRoster] and [newFreeAgents] always change together
  /// -- a signed player leaves [freeAgents] and joins [roster] in the same
  /// instant (`current_franchise_provider.dart`'s `signFreeAgent`), and a
  /// dropped player does the reverse (`dropPlayer`) -- never just one side
  /// or the other.
  Franchise copyWithRosterAndFreeAgents({
    required List<RosterMembership> newRoster,
    required List<Player> newFreeAgents,
  }) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: newRoster,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
      freeAgents: newFreeAgents,
      readMailIds: readMailIds,
    );
  }

  /// Returns a copy with [newReadMailIds] replacing [readMailIds] --
  /// `current_franchise_provider.dart`'s `markMailRead` is the only
  /// caller.
  Franchise copyWithReadMailIds(Set<String> newReadMailIds) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: roster,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: league,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      trainingReports: trainingReports,
      freeAgents: freeAgents,
      readMailIds: newReadMailIds,
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
