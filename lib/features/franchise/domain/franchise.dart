import '../../coach/domain/coach.dart';
import '../../draft/domain/draft_in_progress.dart';
import '../../draft/domain/draft_prospect.dart';
import '../../league/domain/initial_league.dart';
import '../../league/domain/league.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../roster/domain/roster_membership.dart';
import '../../season/domain/season_progress.dart';
import '../../season/domain/skills_competition.dart';
import '../../trade/domain/pick_ownership.dart';
import '../../training/domain/training_coach.dart';
import '../../training/domain/training_plan.dart';
import '../../portrait/domain/portrait_appearance.dart';
import '../../training/domain/training_report.dart';
import 'pending_retirement.dart';

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
    this.pendingRetirements = const [],
    this.draftClass = const [],
    this.draftInProgress,
    this.seasonStartOverallByPlayerId = const {},
    this.narrativeVeteranPlayerId = '',
    this.narrativeVeteranName = '',
    this.narrativeVeteranAppearance,
    this.tradeBlockPlayerId,
    this.resolvedTradeOfferIds = const {},
    this.pickOwnershipOverrides = const {},
    this.narrativeVeteranRetired = false,
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

  /// GM-own-roster players currently waiting on a retirement decision --
  /// see [PendingRetirement]'s own doc comment. Populated at season end
  /// (`current_franchise_provider.dart`'s `simulatePostseasonAndPersist`)
  /// and drained one at a time as the GM actually resolves each one
  /// (`resolvePendingRetirement`) -- unlike [trainingReports]/
  /// [seasonEndAgingResults], this deliberately survives a season
  /// transition ([copyWithNewSeason] carries it forward untouched) rather
  /// than resetting, since an unresolved decision shouldn't just vanish
  /// because a new season started.
  final List<PendingRetirement> pendingRetirements;

  /// This season's real, persisted draft-eligible prospects
  /// (`draft_generator.dart`'s `generateDraftClass`) -- `0D_Season_2_Roadmap.md`'s
  /// Player pool refresh stage: every "class" shown anywhere before this
  /// (the Market screen's Draft tab preview, Season Recap's projected
  /// pick) was a regenerate-fresh-every-render preview, never real saved
  /// data. Set once per season transition ([copyWithNewSeason]'s own
  /// caller, `season_transition_advancer.dart`'s `beginNextSeason`) --
  /// unlike [pendingRetirements], a fresh class fully *replaces* the
  /// previous season's rather than accumulating: last year's undrafted
  /// prospects don't stay draft-eligible into a new class.
  final List<DraftProspect> draftClass;

  /// This season's real draft, mid-resolution -- `0D_Season_2_Roadmap.md`'s
  /// "The draft, for real" stage. `null` whenever no draft is currently
  /// underway (the common case -- most of a season, and before the first
  /// draft ever runs). Set by `season_transition_advancer.dart`'s
  /// `beginNextSeason` alongside a fresh [draftClass], and cleared again
  /// once `draft_advancer.dart`'s `finalizeDraft` lands every pick on a
  /// roster.
  final DraftInProgress? draftInProgress;

  /// Every player's [PlayerRatings.overall] snapshotted the moment *this*
  /// season began -- `season_transition_advancer.dart`'s `beginNextSeason`
  /// is the only writer, capturing it fresh (fully replacing, not merging)
  /// right before that season's own training/aging ever runs.
  /// `season_awards_advancer.dart`'s `resolveSeasonAwards` is the only
  /// reader, at that same season's *end* -- Most Improved Player is
  /// exactly "current overall minus this." Empty for season 0 (no prior
  /// `beginNextSeason` call ever ran to capture it) and for anyone who
  /// joined the league after the snapshot was taken (a mid-season draft
  /// pick or free-agent signing) -- both cases are meant to just be
  /// excluded from Most Improved Player, not crash.
  final Map<String, int> seasonStartOverallByPlayerId;

  /// The [Player.id] of this franchise's hand-placed "grizzled vet"
  /// narrative slot (`starting_roster_generator.dart`'s roster index 0,
  /// age 33-34, ~87 OVR/~88 POT at generation) -- captured once, at
  /// creation, by `expansion_franchise_factory.dart`'s
  /// `createExpansionFranchise` (`roster.first.player.id` is reliably
  /// her: only *positions* get shuffled per-franchise, never the roster
  /// list order). Empty string for any `Franchise` built by hand rather
  /// than through the real onboarding factory (most test fixtures) --
  /// there's no veteran to point at in that case, and nothing reads this
  /// as a match against a real player id unless it's actually set.
  ///
  /// What the "Matchup Analysis" pre-game screen's Analyst panel
  /// (`matchup/domain/analyst.dart`) uses to decide whether seat 1 (a
  /// direct GM ask, 2026-08-12) still shows the generic
  /// [kNarrativeVeteranSeatFallback] look or her own real, retired
  /// portrait -- keyed off [narrativeVeteranRetired], not roster
  /// presence: she's tradeable like anyone else now, so "not found in
  /// [roster]" stopped being a reliable "she retired" signal the moment
  /// trading shipped (2026-08-19) -- see [narrativeVeteranRetired]'s own
  /// doc comment for the real trigger.
  final String narrativeVeteranPlayerId;

  /// The narrative veteran's real generated name, captured alongside
  /// [narrativeVeteranPlayerId] -- what the Analyst panel displays for
  /// seat 1 once she's taken it over for real, replacing the generic
  /// "Preston" label.
  final String narrativeVeteranName;

  /// The narrative veteran's real generated [PortraitAppearance],
  /// snapshotted alongside [narrativeVeteranPlayerId]/[narrativeVeteranName]
  /// so her face survives her leaving [roster] -- nothing else in this
  /// codebase keeps a retired player's data around otherwise (confirmed:
  /// no alumni/retired-player registry exists anywhere). `null` when
  /// [Franchise] was built without `portraitWeights` (same reason
  /// [Coach.appearance]/[Player.appearance] are nullable) -- the seat
  /// falls back to the generic look rather than crashing.
  final PortraitAppearance? narrativeVeteranAppearance;

  /// The GM's own flagged trade-block player -- `null` when nothing's
  /// flagged. Exactly one at a time (`trading-and-hidden-gems-notes.md`:
  /// "only one allowed") -- setting a new one replaces whatever was
  /// there, rather than needing a separate clear-first step.
  /// `trade_offer_generator.dart`'s `generateTradeOffers` reads this to
  /// bias 3 of the 5 generated offers toward this specific player.
  final String? tradeBlockPlayerId;

  /// [TradeOffer.id]s the GM has already accepted or declined *this
  /// turn* -- `trade_offer_generator.dart` regenerates all 5 offers
  /// deterministically from the same seed every time the Trade Board
  /// screen opens (same "cheap to regenerate, nothing to persist"
  /// posture the Player Market preview tabs already use), so without
  /// this, reopening the board after resolving an offer would show that
  /// exact same offer again, unresolved. Reset to empty the moment a new
  /// game day is advanced into (`current_franchise_provider.dart`'s
  /// advance methods) -- a stale id from a past turn should never
  /// suppress a freshly (re)generated offer that just happens to land on
  /// the same deterministic id again.
  final Set<String> resolvedTradeOfferIds;

  /// Which team currently owns each pick across every still-tradeable
  /// future draft, if any have been traded -- `pick_ownership.dart`'s
  /// `FuturePickOwnershipOverrides`, keyed by draft season
  /// (`tradeableDraftSeasons`: the next draft plus one more out, "at
  /// least one season out" per a direct GM call, 2026-08-19). Empty for
  /// almost the whole game (most picks never trade hands);
  /// `acceptTradeOffer` is the only writer during a season.
  /// `season_transition_advancer.dart`'s `beginNextSeason` slices off
  /// just the season *now* starting its draft into a frozen
  /// `DraftInProgress.pickOwnershipOverrides` snapshot and removes that
  /// slice here -- every other season's entries (the ones still further
  /// out) carry forward untouched rather than resetting.
  final FuturePickOwnershipOverrides pickOwnershipOverrides;

  /// Whether `narrativeVeteranPlayerId` has been forced into
  /// retirement yet -- `retirement_advancer.dart`'s
  /// `resolveNarrativeVeteranRetirement` sets this exactly once, at
  /// the end of the franchise's first season, wherever she is by
  /// then (the GM's own roster, an AI team she was traded to, or
  /// dropped to `freeAgents`). What `match_preview_screen.dart`'s
  /// seat-1 Analyst swap keys off -- a real, trade-proof signal,
  /// replacing the old "not found on the GM's own roster" proxy that
  /// broke the instant she was traded away.
  final bool narrativeVeteranRetired;

  /// Returns a copy with [newDraftInProgress] replacing [draftInProgress] --
  /// `draft_advancer.dart` is the only caller so far, both to advance AI
  /// picks and to record the GM's own, and finally to clear it (`null`)
  /// once the draft is finalized.
  Franchise copyWithDraftInProgress(DraftInProgress? newDraftInProgress) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: newDraftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newSnapshot] replacing
  /// [seasonStartOverallByPlayerId] -- `season_transition_advancer.dart`'s
  /// `beginNextSeason` is the only caller.
  Franchise copyWithSeasonStartOverallByPlayerId(Map<String, int> newSnapshot) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: newSnapshot,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newDraftClass] replacing [draftClass] --
  /// `season_transition_advancer.dart`'s `beginNextSeason` is the only
  /// caller so far.
  Franchise copyWithDraftClass(List<DraftProspect> newDraftClass) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: newDraftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newFreeAgents] replacing [freeAgents] -- unlike
  /// [copyWithRosterAndFreeAgents], [roster] itself is untouched here.
  /// What a player joining the pool from somewhere *other* than the GM's
  /// own roster uses -- an AI team waiving a roster-legality excess
  /// (`roster_legality_advancer.dart`'s `enforceAiRosterLegality`, the
  /// only caller so far) never touches [Franchise.roster] at all.
  Franchise copyWithFreeAgents(List<Player> newFreeAgents) {
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
      freeAgents: newFreeAgents,
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newTradeBlockPlayerId] replacing
  /// [tradeBlockPlayerId] -- `current_franchise_provider.dart`'s
  /// `setTradeBlockPlayer` is the only caller. `null` clears it.
  Franchise copyWithTradeBlockPlayerId(String? newTradeBlockPlayerId) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: newTradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newResolvedTradeOfferIds] replacing
  /// [resolvedTradeOfferIds] -- `current_franchise_provider.dart`'s
  /// `acceptTradeOffer`/`declineTradeOffer` add to it; every game-day
  /// advance method resets it to empty (see that field's own doc
  /// comment for why).
  Franchise copyWithResolvedTradeOfferIds(
    Set<String> newResolvedTradeOfferIds,
  ) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: newResolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newPickOwnershipOverrides] replacing
  /// [pickOwnershipOverrides] -- `current_franchise_provider.dart`'s
  /// `acceptTradeOffer` is the only in-season writer (transferring one
  /// pick at a time via `pick_ownership.dart`'s
  /// `transferFuturePickOwnership`); `season_transition_advancer.dart`'s
  /// `beginNextSeason` is the only caller that removes a season's worth
  /// (the one whose draft it just baked into the fresh `DraftInProgress`
  /// it builds) rather than adding one.
  Franchise copyWithPickOwnershipOverrides(
    FuturePickOwnershipOverrides newPickOwnershipOverrides,
  ) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: newPickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newNarrativeVeteranRetired] replacing
  /// [narrativeVeteranRetired] -- `retirement_advancer.dart`'s
  /// `resolveNarrativeVeteranRetirement` is the only caller, and only
  /// ever writes `true` (this never resets back to `false`).
  Franchise copyWithNarrativeVeteranRetired(bool newNarrativeVeteranRetired) {
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
      readMailIds: readMailIds,
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: newNarrativeVeteranRetired,
    );
  }

  /// Returns a copy with [newPendingRetirements] replacing
  /// [pendingRetirements] -- `current_franchise_provider.dart`'s
  /// `resolvePendingRetirement` (a GM decision resolving one) and
  /// `simulatePostseasonAndPersist` (a fresh season's newly-eligible
  /// players) are the only callers.
  ///
  /// Fixed 2026-08-12: this constructor call used to omit [draftClass],
  /// [draftInProgress], and [seasonStartOverallByPlayerId] entirely,
  /// which meant every call silently reset all three to the main
  /// constructor's own defaults (empty list, `null`, empty map) instead
  /// of preserving them -- caught while adding [narrativeVeteranPlayerId]
  /// and its siblings here and noticing every *other* `copyWithX` method
  /// threads every field through. Whether this had a live symptom depends
  /// on timing (a draft in progress or an un-consumed season-start
  /// snapshot at the exact moment a retirement resolves), but it was
  /// wrong regardless of whether it had ever been observed.
  Franchise copyWithPendingRetirements(
    List<PendingRetirement> newPendingRetirements,
  ) {
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
      readMailIds: readMailIds,
      pendingRetirements: newPendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
      pendingRetirements: pendingRetirements,
      draftClass: draftClass,
      draftInProgress: draftInProgress,
      seasonStartOverallByPlayerId: seasonStartOverallByPlayerId,
      narrativeVeteranPlayerId: narrativeVeteranPlayerId,
      narrativeVeteranName: narrativeVeteranName,
      narrativeVeteranAppearance: narrativeVeteranAppearance,
      tradeBlockPlayerId: tradeBlockPlayerId,
      resolvedTradeOfferIds: resolvedTradeOfferIds,
      pickOwnershipOverrides: pickOwnershipOverrides,
      narrativeVeteranRetired: narrativeVeteranRetired,
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
