import 'dart:math';

import '../../league/domain/team.dart';
import '../domain/game_day.dart';
import '../domain/scheduled_game.dart';
import '../domain/season_schedule.dart';
import 'all_star_generator.dart';

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

/// "Week 0" for [kPreseasonWeek], "Week $week" otherwise -- a display-only
/// override (2026-08-07, a direct GM ask: "can we call Preseason Week
/// 0?"). The stored week number itself is untouched -- this doesn't
/// renumber the calendar, it just relabels the one week nothing else
/// ever shares with preseason.
String weekLabel(int week) => week == kPreseasonWeek ? 'Week 0' : 'Week $week';

/// Regular season/Continental Cup game days (`0B_Planned.md`'s declared
/// game days) -- a team can be booked on each at most once per week, which
/// is also where the "2 games per team per week" cap comes from: it's a
/// consequence of there being 2 available days, not a separately-enforced
/// number.
const _regularSeasonGameDays = [GameDay.sunday, GameDay.thursday];

/// The day Continental Cup Round 1 (and, in `continental_cup_generator.dart`,
/// every later round) is played on. Cup rounds each get a dedicated week
/// with only one game per team, so unlike the regular season there's no
/// need to spread a team's games across multiple days within the round's
/// week.
const kContinentalCupGameDay = GameDay.thursday;

/// Generates one season's schedule for [leagueTeams] -- this playthrough's
/// full 20-team league (19 AI teams + the GM's own club substituted in for
/// the one it replaced, the same shape `LeagueScreen` already builds).
/// Deterministic for a given [random] stream.
///
/// Produces:
/// - **Preseason** (week [kPreseasonWeek]): 2 inter-conference games per
///   team, via two independent random pairings between the conferences --
///   one on [GameDay.sunday], one on [GameDay.thursday].
/// - **Regular season** (weeks [kRegularSeasonStartWeek]-
///   [kRegularSeasonEndWeek]): 28 games per team -- a full double
///   round-robin within each 10-team conference (18 games) plus a single
///   round-robin against the other conference (10 games) -- greedily
///   packed into (week, day) slots so no team is ever double-booked on the
///   same day. Week/day assignment is a simple greedy pack, not a fully
///   realistic pacing model (back-to-backs against the same opponent
///   aren't specially avoided) -- outcome (right games, right counts,
///   right week range) matters more than mechanism here, same as AI
///   roster generation.
/// - **Continental Cup Round 1** (week [kContinentalCupRound1Week]): all
///   20 teams randomly seeded into 10 games. Rounds 2-5 depend on results
///   that don't exist yet -- see the note on [SeasonSchedule].
/// - **All-Star week** (week [kAllStarWeek], `all_star_generator.dart`):
///   2 placeholder entries -- the Skills Competition and the All-Star
///   Game -- so both surface in `gameDaysInOrder` like any other game
///   day. Neither is scheduled or resolved like a normal team game; see
///   that file's own doc comments.
///
/// Note: Continental Cup Round 1 lands inside the regular season's week
/// range (week 4) and every team plays exactly one Round 1 game there --
/// [_assignRegularSeasonWeeks] pre-books that exact (week, day) for every
/// team before it packs anything else in, so a team never ends up with a
/// regular-season game *and* its Cup game on the same nominal day (fixed
/// 2026-08-07; previously unaccounted-for). Rounds 2-5 don't get the same
/// treatment -- their (week, day) is fixed too (`kContinentalCupRound2Week`
/// etc.), but which teams actually play them isn't known until the round
/// before finishes, so pre-booking a slot for literally every team would
/// waste real regular-season capacity on teams that will already be
/// eliminated. Still open, same as before this fix.
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
      ..._assignRegularSeasonWeeks(regularSeasonPairs, leagueTeams, random),
      ..._generateContinentalCupRound1(leagueTeams, random),
      ...generateAllStarWeekGames(),
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
    final day = _regularSeasonGameDays[pass];
    for (var i = 0; i < shuffledAtlantic.length; i++) {
      final home = pass.isEven ? shuffledAtlantic[i] : shuffledPacific[i];
      final away = pass.isEven ? shuffledPacific[i] : shuffledAtlantic[i];
      games.add(
        ScheduledGame(
          week: kPreseasonWeek,
          day: day,
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
  List<Team> leagueTeams,
  Random random,
) {
  final shuffledPairs = List<(Team, Team)>.of(pairs)..shuffle(random);
  final bookedDaysByTeamAndWeek = <String, Map<int, Set<GameDay>>>{};

  Set<GameDay> bookedDaysFor(String abbreviation, int week) =>
      bookedDaysByTeamAndWeek[abbreviation]?[week] ?? const {};

  void book(String abbreviation, int week, GameDay day) {
    bookedDaysByTeamAndWeek
        .putIfAbsent(abbreviation, () => {})
        .putIfAbsent(week, () => {})
        .add(day);
  }

  // Every team plays a Continental Cup Round 1 game at this exact
  // (week, day) -- reserve it up front so the greedy pack below never
  // lands a regular-season game there too. 17 weeks x 2 days = 34
  // team-slots against 28 games/team, so losing 1 slot to the Cup still
  // leaves comfortable slack (see the assert in
  // [_assignOneGameWeekAndDay]).
  for (final team in leagueTeams) {
    book(team.abbreviation, kContinentalCupRound1Week, kContinentalCupGameDay);
  }

  return [
    for (final (home, away) in shuffledPairs)
      _assignOneGameWeekAndDay(home, away, bookedDaysFor, book),
  ];
}

ScheduledGame _assignOneGameWeekAndDay(
  Team home,
  Team away,
  Set<GameDay> Function(String abbreviation, int week) bookedDaysFor,
  void Function(String abbreviation, int week, GameDay day) book,
) {
  int? assignedWeek;
  GameDay? assignedDay;
  for (
    var week = kRegularSeasonStartWeek;
    week <= kRegularSeasonEndWeek && assignedWeek == null;
    week++
  ) {
    final homeBooked = bookedDaysFor(home.abbreviation, week);
    final awayBooked = bookedDaysFor(away.abbreviation, week);
    for (final day in _regularSeasonGameDays) {
      if (!homeBooked.contains(day) && !awayBooked.contains(day)) {
        assignedWeek = week;
        assignedDay = day;
        break;
      }
    }
  }
  assert(
    assignedWeek != null,
    'could not find a week/day for ${home.abbreviation} vs '
    '${away.abbreviation} within the ${_regularSeasonGameDays.length} '
    'game days per week -- the regular season\'s 17-week window should '
    'always have enough slack for 28 games per team',
  );

  book(home.abbreviation, assignedWeek!, assignedDay!);
  book(away.abbreviation, assignedWeek, assignedDay);
  return ScheduledGame(
    week: assignedWeek,
    day: assignedDay,
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
        day: kContinentalCupGameDay,
        homeTeamAbbreviation: shuffled[i].abbreviation,
        awayTeamAbbreviation: shuffled[i + 1].abbreviation,
        type: GameType.continentalCup,
        continentalCupRound: 1,
      ),
  ];
}
