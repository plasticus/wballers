import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../domain/game_day.dart';
import '../domain/league_leaders.dart';
import '../domain/scheduled_game.dart';

/// The season calendar week the All-Star break falls on -- a direct GM
/// ask: "let's put it like 80% of the way through the season." 19/24
/// (`season_schedule_generator.dart`'s full week range, preseason through
/// the postseason Finals) is ~79%, and week 19 is also the schedule's one
/// naturally free week already -- nothing else is ever scheduled between
/// [kRegularSeasonEndWeek] (18) and [kPostseasonFirstRoundWeek] (20), so
/// landing here needs no changes to the regular season's tightly-packed
/// round-robin slotting. The trade-off, worth knowing: since the regular
/// season is already fully played out by week 19, All-Star squad
/// selection uses *final* regular-season stats, not a mid-season
/// snapshot with games still to come -- more like end-of-season honors
/// than a true mid-season pause. Moving this earlier (genuinely
/// mid-regular-season) would mean carving a week out of the round-robin
/// packing itself, a riskier change to that algorithm's slack guarantees
/// -- left as potential follow-up, not done here.
const kAllStarWeek = 19;

/// [GameDay]'s declared order (`game_day.dart`: sunday, tuesday, thursday)
/// is also its *within-week* chronological/sort order --
/// `gameDaysInOrder` sorts by `(week, day.index)`, and Sunday really does
/// fall before Thursday in the same calendar week (day offsets 0 and 4).
/// The GM's ask was Thursday-skills-then-Sunday-game, which is only true
/// calendar order if the Sunday is the *following* week's -- but every
/// other week number is already spoken for (postseason claims the very
/// next one, [kPostseasonFirstRoundWeek]), so both events stay inside
/// [kAllStarWeek] and use whichever [GameDay] values actually sort in
/// the right order instead: Sunday resolves first here, so the Skills
/// Competition uses it despite the mismatch with the GM's literal
/// weekday; Thursday resolves second, so the Game uses that. Neither
/// value is ever shown to the GM as a real weekday for these 2 events --
/// the dedicated result screens print "Skills Competition"/"All-Star
/// Game" plus the real calendar date, never `GameDay.label`, specifically
/// to avoid surfacing this mismatch.
const kSkillsCompetitionDay = GameDay.sunday;
const kAllStarGameDay = GameDay.thursday;

/// Placeholder "team" identities for the 2 conference All-Star squads --
/// not real [Team]s (no entry in `kLeagueTeamPool`, never returned by
/// `allLeagueTeams`), just enough of an abbreviation for [ScheduledGame]/
/// `rostersByAbbreviation` to carry the squad through the exact same
/// game-day/match-engine plumbing every other game already uses. UI code
/// must never resolve these through `teamByAbbreviation` (it would throw,
/// same as any abbreviation outside the real 20-team league) -- the
/// dedicated All-Star result screens use [Conference.label] instead.
const kAtlanticAllStarsAbbreviation = 'ATL-AS';
const kPacificAllStarsAbbreviation = 'PAC-AS';

/// The 2 All-Star week entries [generateSeasonSchedule] appends to every
/// new franchise's schedule: the Skills Competition on
/// [kSkillsCompetitionDay], the All-Star Game on [kAllStarGameDay], both
/// at [kAllStarWeek]. Both use the same placeholder home/away pair --
/// meaningful for the All-Star Game (literally Atlantic vs Pacific), just
/// a shape-satisfying placeholder for the Skills Competition (an
/// individual, not team-vs-team, event -- see [kAtlanticAllStarsAbbreviation]'s
/// own doc comment). Having a real [ScheduledGame] for both is what gets
/// them into `gameDaysInOrder` for free, so "advance to the next game
/// day" walks through this week exactly like any other, no special
/// handling needed in `season_progress.dart`.
List<ScheduledGame> generateAllStarWeekGames() => const [
  ScheduledGame(
    week: kAllStarWeek,
    day: kSkillsCompetitionDay,
    homeTeamAbbreviation: kAtlanticAllStarsAbbreviation,
    awayTeamAbbreviation: kPacificAllStarsAbbreviation,
    type: GameType.skillsCompetition,
  ),
  ScheduledGame(
    week: kAllStarWeek,
    day: kAllStarGameDay,
    homeTeamAbbreviation: kAtlanticAllStarsAbbreviation,
    awayTeamAbbreviation: kPacificAllStarsAbbreviation,
    type: GameType.allStarGame,
  ),
];

/// One conference's 10 All-Star honorees, grouped by the position they
/// earned the honor at -- the top 2 by [PlayerSeasonTotals.mvpScore] at
/// each of the 5 [Position]s (2026-08-10, a direct GM ask: "top 2 players
/// at each position per conference"). [mvpScore] is the same simple,
/// transparent composite the Stats tab's own MVP Race already uses --
/// adopting it here rather than inventing a second ranking formula.
///
/// A player with no [PlayerSeasonTotals] at all (never appeared in a
/// played regular-season game -- hurt the whole year, signed very late,
/// etc.) scores 0 and simply won't rank among the top 2 at a competitive
/// position; there's no separate eligibility floor beyond that.
List<Player> selectConferenceAllStars({
  required Conference conference,
  required List<Team> leagueTeams,
  required Map<String, List<Player>> rostersByAbbreviation,
  required Map<String, PlayerSeasonTotals> leaders,
}) {
  final conferencePlayers = [
    for (final team in leagueTeams)
      if (team.conference == conference)
        ...?rostersByAbbreviation[team.abbreviation],
  ];

  double scoreOf(Player player) => leaders[player.id]?.mvpScore ?? 0;

  return [
    for (final position in Position.values)
      ...(conferencePlayers
              .where((player) => player.primaryPosition == position)
              .toList()
            ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a))))
          .take(2),
  ];
}

/// Every player in [leagueTeams]/[rostersByAbbreviation] on
/// [conference]'s teams, ranked by [mvpScore] but *not* already in
/// [excludeIds] -- what [resolveAllStarGame] uses to fill a 10-honoree
/// squad out to a legal 12-player roster (`substitution_policy.dart`
/// expects exactly 12) without minting fake players. These extra 2 are
/// squad depth for simulation purposes only -- never real All-Stars, so
/// callers must keep them out of anything display- or achievement-facing
/// (the box score displays fine either way, but MVP eligibility and the
/// "who made the team" summary both key off the 10-per-conference
/// honoree list, not the full 12-player sim roster).
List<Player> nextBestConferencePlayers({
  required Conference conference,
  required List<Team> leagueTeams,
  required Map<String, List<Player>> rostersByAbbreviation,
  required Map<String, PlayerSeasonTotals> leaders,
  required Set<String> excludeIds,
  required int count,
}) {
  double scoreOf(Player player) => leaders[player.id]?.mvpScore ?? 0;
  final pool =
      [
          for (final team in leagueTeams)
            if (team.conference == conference)
              ...?rostersByAbbreviation[team.abbreviation],
        ].where((player) => !excludeIds.contains(player.id)).toList()
        ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
  return pool.take(count).toList();
}
