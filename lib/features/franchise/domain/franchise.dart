import '../../coach/domain/coach.dart';
import '../../league/domain/initial_league.dart';
import '../../league/domain/league.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import '../../season/domain/season_progress.dart';
import '../../season/domain/skills_competition.dart';
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
/// Each season gets its own slice of the seed space, [kSeasonSeedSpan]
/// wide -- see [Franchise.seasonSeed]. 10,000 is comfortably larger than
/// any single generator's own internal variation ever gets within one
/// season (a game-day index maxes out in the 40s, a training week in the
/// 20s, seed-offset constants themselves stay in the teens), so no two
/// seasons' seeds can ever collide regardless of how many more per-season
/// generators/offsets get added later.
const kSeasonSeedSpan = 10000;

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
    this.season = 0,
    this.trainingReports = const [],
    this.seasonEndAgingResults = const [],
    this.skillsCompetitionResults = const [],
    this.freeAgents = const [],
    this.readMailIds = const {},
  }) : assert(season >= 0, 'season must not be negative'),
       assert(
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
  /// results. Combine with [season] via [seasonSeed] for anything that
  /// resolves once per season (or more) rather than once ever at
  /// franchise creation -- see that getter's own doc comment.
  final int simulationSeed;

  /// A zero-based counter -- 0 for a franchise's first season, same
  /// "zero-based" convention `PlayerAchievementRecord.season` already
  /// uses. Everything that resolves once per season (game-day/postseason/
  /// training advancement, season-end aging, AI-team training, the
  /// schedule itself) needs this folded into its own seed
  /// ([seasonSeed]) so a second season doesn't just silently replay the
  /// first's random rolls (`0D_Season_2_Roadmap.md`'s Foundation item 2).
  /// [beginNextSeason] (`season_transition_advancer.dart`) is the only
  /// place this ever increments.
  final int season;

  /// [simulationSeed], shifted into this season's own [kSeasonSeedSpan]-wide
  /// slice of the seed space -- what every *per-season* generator should
  /// seed off (`Random(franchise.seasonSeed + kSomeOffset + ...)`), instead
  /// of [simulationSeed] directly. Generators that only ever run once, at
  /// franchise creation (the coach, the starting roster, the league draw
  /// and its AI rosters, the 3 training coaches) stay on plain
  /// [simulationSeed] -- they never run again regardless of [season], and
  /// `league_screen.dart`'s own re-derivation of the original league draw
  /// specifically depends on reproducing that exact original roll, not a
  /// season-shifted one.
  int get seasonSeed => simulationSeed + season * kSeasonSeedSpan;

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

  /// Every training report so far this season -- what the Mail tab
  /// (`mail/application/mailbox.dart`'s `mailboxFor`) lists a
  /// `TrainingReportMailItem` for, one per entry. Lean by construction
  /// (`TrainingReport` only records players who actually changed), so
  /// keeping the whole season's worth doesn't meaningfully grow the save.
  final List<TrainingReport> trainingReports;

  /// The one-time off-season aging lump's own results
  /// (`training/generation/training_advancer.dart`'s
  /// `resolveSeasonEndAging`) -- empty until a season's postseason bracket
  /// actually finishes. Deliberately not folded into [trainingReports]:
  /// that list means "one schedule week's worth of minutes-and-coaching
  /// training," and every entry in it automatically becomes a Mail inbox
  /// item and a Dashboard training-report card
  /// (`mail/application/mailbox.dart`, `dashboard_screen.dart`) -- the
  /// off-season lump is a different concept (age alone, no minutes/coach
  /// involved) that `SeasonRecapScreen`'s player-development section
  /// reads directly rather than surfacing through either of those. Only
  /// ever one season's worth right now -- there's no multi-season flow
  /// yet (`0B_Planned.md`) to reset or accumulate a history across, so
  /// this simply gets overwritten if a season somehow re-resolved (which
  /// [current_franchise_provider.dart]'s `simulatePostseasonAndPersist`
  /// already guards against in practice).
  final List<PlayerGrowthResult> seasonEndAgingResults;

  /// The All-Star break's Skills Competition, once it's resolved
  /// (2026-08-10, TODO.md item 6) -- also the one persisted record of
  /// which players made each conference's All-Star squad that season
  /// (`SkillsCompetitionResult.squads`), which `resolveAllStarGame`
  /// (`all_star_advancer.dart`) reads back rather than re-deriving. A
  /// list for the same forward-looking reason [trainingReports] is --
  /// only ever one entry right now (there's no multi-season flow yet),
  /// but the shape doesn't assume that.
  final List<SkillsCompetitionResult> skillsCompetitionResults;

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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
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
      season: season,
      trainingReports: [...trainingReports, newReport],
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
      freeAgents: freeAgents,
      readMailIds: readMailIds,
    );
  }

  /// Returns a copy reflecting the one-time off-season aging lump having
  /// resolved: [newRoster] carries whatever decline it produced, and
  /// [newResults] replaces [seasonEndAgingResults] outright (not
  /// appended -- there's only ever one season's worth right now, see
  /// [seasonEndAgingResults]'s own doc comment).
  /// `training_advancer.dart`'s `resolveSeasonEndAging` is the only
  /// producer of both.
  Franchise copyWithSeasonEndAging({
    required List<RosterMembership> newRoster,
    required List<PlayerGrowthResult> newResults,
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: newResults,
      skillsCompetitionResults: skillsCompetitionResults,
      freeAgents: freeAgents,
      readMailIds: readMailIds,
    );
  }

  /// Returns a copy with [newResult] appended to [skillsCompetitionResults]
  /// -- `all_star_advancer.dart`'s `resolveSkillsCompetitionDay` is the
  /// only producer.
  Franchise copyWithSkillsCompetitionResult(SkillsCompetitionResult newResult) {
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: [...skillsCompetitionResults, newResult],
      freeAgents: freeAgents,
      readMailIds: readMailIds,
    );
  }

  /// Returns a copy with [newLeague] replacing [league] -- currently only
  /// [resolveAiTeamSeasonTraining]'s doing (`training_advancer.dart`),
  /// which is the one thing that ever changes an AI team's roster after
  /// franchise creation.
  Franchise copyWithLeague(League newLeague) {
    return Franchise(
      id: id,
      gmName: gmName,
      team: team,
      coach: coach,
      roster: roster,
      simulationSeed: simulationSeed,
      replacedTeamAbbreviation: replacedTeamAbbreviation,
      league: newLeague,
      seasonProgress: seasonProgress,
      trainingCoaches: trainingCoaches,
      trainingPlan: trainingPlan,
      nextTrainingWeek: nextTrainingWeek,
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
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
      season: season,
      trainingReports: trainingReports,
      seasonEndAgingResults: seasonEndAgingResults,
      skillsCompetitionResults: skillsCompetitionResults,
      freeAgents: freeAgents,
      readMailIds: newReadMailIds,
    );
  }

  /// Returns a copy reflecting a full season transition -- [newSeason]
  /// replaces [season] (always `season + 1`; `beginNextSeason`,
  /// `season_transition_advancer.dart`, is the only caller, and asserts
  /// that itself), [newSeasonProgress] is the freshly generated schedule
  /// with nothing played yet, and [roster]/[league] are deliberately
  /// **not** touched here -- aging, retirement, and roster-legality
  /// enforcement are separate, not-yet-built stages
  /// (`0D_Season_2_Roadmap.md`'s "Aging & churn"), so this Foundation-only
  /// version of the transition carries every player over completely
  /// unchanged.
  ///
  /// [trainingReports]/[seasonEndAgingResults]/[skillsCompetitionResults]
  /// all reset to empty and [nextTrainingWeek] resets to 1 -- a direct GM
  /// answer on exactly this (`season2roadmap.md` answer 3): "Off-season,
  /// both [mail and training reports] get cleared... end-of-season
  /// reports and season awards stay visible forever" -- the "stay visible
  /// forever" half isn't built yet either (there's no historical archive
  /// to move last season's recap into), but at minimum a new season must
  /// not start with last season's reports still sitting in Mail.
  /// [readMailIds] is left alone -- harmless stale ids, nothing left to
  /// match against once their source data is gone.
  Franchise copyWithNewSeason({
    required int newSeason,
    required SeasonProgress newSeasonProgress,
  }) {
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
      nextTrainingWeek: 1,
      season: newSeason,
      trainingReports: const [],
      seasonEndAgingResults: const [],
      skillsCompetitionResults: const [],
      freeAgents: freeAgents,
      readMailIds: readMailIds,
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
