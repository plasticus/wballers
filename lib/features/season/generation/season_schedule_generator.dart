import 'dart:math';

import '../../league/domain/team.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_schedule.dart';

/// Seed offset for schedule generation -- keeps this random stream from
/// correlating with the coach (0), starting roster (1), league draw (2),
/// or league AI rosters (3) streams, same pattern as those.
const kSeasonScheduleSeedOffset = 4;

/// Season calendar week numbers (`0B_Planned.md`'s 24-week table).
const kPreseasonWeek = 1;
const kRegularSeasonStartWeek = 2;
const kRegularSeasonEndWeek = 18;
const kContinentalCupRound1Week = 4;
const kContinentalCupRound2Week = 6;
const kContinentalCupRound3Week = 8; // Quarterfinals
const kContinentalCupRound4Week = 10; // Semifinals
const kContinentalCupRound5Week = 12; // Final
const kPostseasonFirstRoundWeek = 20;
const kPostseasonSemifinalsWeek = 22;
const kPostseasonFinalsWeek = 24;

/// Cap on how many games a single team can be scheduled for in the same
/// week when packing the regular season into its 17-week window (weeks
/// [kRegularSeasonStartWeek]-[kRegularSeasonEndWeek]). 28 games per team
/// across 17 weeks needs some weeks with 2 games (17 * 2 = 34 available
/// slots, comfortable headroom over the 28 needed) -- this just stops any
/// single week from stacking up 3+ games for one team.
const _maxGamesPerTeamPerWeek = 2;

/// Generates one season's schedule for [leagueTeams] -- this playthrough's
/// full 20-team league (19 AI teams + the GM's own club substituted in for
/// the one it replaced, the same shape `LeagueScreen` already builds).
/// Deterministic for a given [random] stream.
///
/// Produces:
/// - **Preseason** (week [kPreseasonWeek]): 2 inter-conference games per
///   team, via two independent random pairings between the conferences.
/// - **Regular season** (weeks [kRegularSeasonStartWeek]-
///   [kRegularSeasonEndWeek]): 28 games per team -- a full double
///   round-robin within each 10-team conference (18 games) plus a single
///   round-robin against the other conference (10 games) -- greedily
///   packed into weeks so no team exceeds [_maxGamesPerTeamPerWeek] games
///   in the same week. Week assignment is a simple greedy pack, not a
///   fully realistic pacing model (back-to-backs against the same
///   opponent aren't specially avoided) -- outcome (right games, right
///   counts, right week range) matters more than mechanism here, same as
///   AI roster generation.
/// - **Continental Cup Round 1** (week [kContinentalCupRound1Week]): all
///   20 teams randomly seeded into 10 games. Rounds 2-5 depend on results
///   that don't exist yet -- see the note on [SeasonSchedule].
SeasonSchedule generateSeasonSchedule(List<Team> leagueTeams, Random random) {
  final atlantic = leagueTeams
      .where((team) => team.conference == Conference.atlantic)
      .toList();
  final pacific = leagueTeams
      .where((team) => team.conference == Conference.pacific)
      .toList();
  assert(
    atlantic.length == 10 && pacific.length == 10,
    'a league is always 10 Atlantic + 10 Pacific teams',
  );

  final regularSeasonPairs = <(Team home, Team away)>[
    ..._intraConferenceDoubleRoundRobin(atlantic),
    ..._intraConferenceDoubleRoundRobin(pacific),
    ..._interConferenceSingleRoundRobin(atlantic, pacific),
  ];

  return SeasonSchedule(
    games: [
      ..._generatePreseason(atlantic, pacific, random),
      ..._assignRegularSeasonWeeks(regularSeasonPairs, random),
      ..._generateContinentalCupRound1(leagueTeams, random),
    ],
  );
}

List<ScheduledGame> _generatePreseason(
  List<Team> atlantic,
  List<Team> pacific,
  Random random,
) {
  final games = <ScheduledGame>[];
  for (var pass = 0; pass < 2; pass++) {
    final shuffledAtlantic = List<Team>.of(atlantic)..shuffle(random);
    final shuffledPacific = List<Team>.of(pacific)..shuffle(random);
    for (var i = 0; i < shuffledAtlantic.length; i++) {
      final home = pass.isEven ? shuffledAtlantic[i] : shuffledPacific[i];
      final away = pass.isEven ? shuffledPacific[i] : shuffledAtlantic[i];
      games.add(
        ScheduledGame(
          week: kPreseasonWeek,
          homeTeamAbbreviation: home.abbreviation,
          awayTeamAbbreviation: away.abbreviation,
          type: GameType.preseason,
        ),
      );
    }
  }
  return games;
}

List<(Team, Team)> _intraConferenceDoubleRoundRobin(
  List<Team> conferenceTeams,
) {
  final pairs = <(Team, Team)>[];
  for (final round in _circleMethodRoundsIndices(conferenceTeams.length)) {
    for (final (i, j) in round) {
      pairs.add((conferenceTeams[i], conferenceTeams[j]));
      pairs.add((conferenceTeams[j], conferenceTeams[i]));
    }
  }
  return pairs;
}

List<(Team, Team)> _interConferenceSingleRoundRobin(
  List<Team> atlantic,
  List<Team> pacific,
) {
  final pairs = <(Team, Team)>[];
  final n = atlantic.length;
  for (var round = 0; round < n; round++) {
    for (var i = 0; i < n; i++) {
      final j = (i + round) % n;
      pairs.add(
        round.isEven ? (atlantic[i], pacific[j]) : (pacific[j], atlantic[i]),
      );
    }
  }
  return pairs;
}

/// Standard "circle method" single round-robin: for an even-sized team
/// count, returns n-1 rounds, each a perfect matching of index pairs
/// (every team appears exactly once per round, every pair exactly once
/// across all rounds).
List<List<(int, int)>> _circleMethodRoundsIndices(int n) {
  assert(n.isEven, 'circle-method round robin needs an even team count');
  final arr = List<int>.generate(n, (i) => i);
  final rounds = <List<(int, int)>>[];
  for (var round = 0; round < n - 1; round++) {
    rounds.add([for (var i = 0; i < n ~/ 2; i++) (arr[i], arr[n - 1 - i])]);
    final last = arr.removeLast();
    arr.insert(1, last);
  }
  return rounds;
}

List<ScheduledGame> _assignRegularSeasonWeeks(
  List<(Team home, Team away)> pairs,
  Random random,
) {
  final shuffledPairs = List<(Team, Team)>.of(pairs)..shuffle(random);
  final gamesPerTeamPerWeek = <String, Map<int, int>>{};

  int countFor(String abbreviation, int week) =>
      gamesPerTeamPerWeek[abbreviation]?[week] ?? 0;

  void increment(String abbreviation, int week) {
    final byWeek = gamesPerTeamPerWeek.putIfAbsent(abbreviation, () => {});
    byWeek[week] = (byWeek[week] ?? 0) + 1;
  }

  return [
    for (final (home, away) in shuffledPairs)
      _assignOneGameWeek(home, away, countFor, increment),
  ];
}

ScheduledGame _assignOneGameWeek(
  Team home,
  Team away,
  int Function(String abbreviation, int week) countFor,
  void Function(String abbreviation, int week) increment,
) {
  int? assignedWeek;
  for (
    var week = kRegularSeasonStartWeek;
    week <= kRegularSeasonEndWeek;
    week++
  ) {
    if (countFor(home.abbreviation, week) < _maxGamesPerTeamPerWeek &&
        countFor(away.abbreviation, week) < _maxGamesPerTeamPerWeek) {
      assignedWeek = week;
      break;
    }
  }
  assert(
    assignedWeek != null,
    'could not find a week for ${home.abbreviation} vs ${away.abbreviation} '
    'within the $_maxGamesPerTeamPerWeek-per-week cap -- the regular '
    'season\'s 17-week window should always have enough slack for 28 '
    'games per team',
  );

  increment(home.abbreviation, assignedWeek!);
  increment(away.abbreviation, assignedWeek);
  return ScheduledGame(
    week: assignedWeek,
    homeTeamAbbreviation: home.abbreviation,
    awayTeamAbbreviation: away.abbreviation,
    type: GameType.regularSeason,
  );
}

List<ScheduledGame> _generateContinentalCupRound1(
  List<Team> leagueTeams,
  Random random,
) {
  final shuffled = List<Team>.of(leagueTeams)..shuffle(random);
  return [
    for (var i = 0; i < shuffled.length; i += 2)
      ScheduledGame(
        week: kContinentalCupRound1Week,
        homeTeamAbbreviation: shuffled[i].abbreviation,
        awayTeamAbbreviation: shuffled[i + 1].abbreviation,
        type: GameType.continentalCup,
        continentalCupRound: 1,
      ),
  ];
}
