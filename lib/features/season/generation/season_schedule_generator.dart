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
///   team, via two random pairings between the conferences -- one on
///   [GameDay.sunday], one on [GameDay.thursday] -- with the second pairing
///   guaranteed to give every team a different opponent than the first
///   (2026-08-21, a GM bug report: two fully independent shuffles can, and
///   did, pair the same two teams together both times by chance).
/// - **Regular season** (weeks [kRegularSeasonStartWeek]-
///   [kRegularSeasonEndWeek]): 28 games per team -- a full double
///   round-robin within each 10-team conference (18 games) plus a single
///   round-robin against the other conference (10 games) -- greedily
///   packed into (week, day) slots so no team is ever double-booked on the
///   same day, then smoothed with a rebalancing pass
///   (`_spreadGamesAcrossWeeks`) so byes land spread across the season
///   instead of piling up at the end. Week/day assignment still isn't a
///   fully realistic pacing model (back-to-backs against the same
///   opponent aren't specially avoided) -- outcome (right games, right
///   counts, right week range, no week left completely empty) matters
///   more than mechanism here, same as AI roster generation.
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
  // Atlantic stays in a fixed order across both passes -- only Pacific
  // gets reshuffled per pass -- which still produces a uniformly random
  // pairing each time (shuffling one side against a fixed other is the
  // same distribution as shuffling both). Keeping Atlantic's order fixed
  // is what lets pass 2 be checked/repaired position-by-position against
  // pass 1 below.
  final pass1Pacific = List<Team>.of(pacific)..shuffle(random);
  var pass2Pacific = List<Team>.of(pacific)..shuffle(random);
  // Rejection-sample for a pairing where nobody repeats their pass-1
  // opponent -- a plain independent shuffle can (and did) land the same
  // pairing twice by chance. 10 teams a side converges in a handful of
  // tries; the attempt cap is just a safety net against a pathological
  // seed spinning forever, with a guaranteed pairwise-swap repair after.
  var attempts = 0;
  while (attempts < 200 &&
      _repeatsAnyPairing(atlantic, pass1Pacific, pass2Pacific)) {
    pass2Pacific = List<Team>.of(pacific)..shuffle(random);
    attempts++;
  }
  pass2Pacific = _repairRepeatedPairings(atlantic, pass1Pacific, pass2Pacific);

  for (var pass = 0; pass < 2; pass++) {
    final shuffledPacific = pass == 0 ? pass1Pacific : pass2Pacific;
    final day = _regularSeasonGameDays[pass];
    for (var i = 0; i < atlantic.length; i++) {
      final home = pass.isEven ? atlantic[i] : shuffledPacific[i];
      final away = pass.isEven ? shuffledPacific[i] : atlantic[i];
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

/// Whether any Atlantic team's [pass2Pacific] opponent matches its
/// [pass1Pacific] opponent, position-by-position (both lists are indexed
/// the same way [atlantic] is).
bool _repeatsAnyPairing(
  List<Team> atlantic,
  List<Team> pass1Pacific,
  List<Team> pass2Pacific,
) {
  for (var i = 0; i < atlantic.length; i++) {
    if (pass2Pacific[i] == pass1Pacific[i]) return true;
  }
  return false;
}

/// Deterministically fixes any leftover repeated pairing
/// [_repeatsAnyPairing] would still flag after the rejection-sampling
/// loop above gives up -- for each repeat at index `i`, swaps
/// `pass2Pacific[i]` with another index whose own pass-2 opponent isn't
/// `pass1Pacific[i]` (always found for a 10-team conference, since at
/// most a handful of positions ever need repair). A no-op list copy when
/// there's nothing left to fix, which is the overwhelmingly common case.
List<Team> _repairRepeatedPairings(
  List<Team> atlantic,
  List<Team> pass1Pacific,
  List<Team> pass2Pacific,
) {
  final repaired = List<Team>.of(pass2Pacific);
  for (var i = 0; i < atlantic.length; i++) {
    if (repaired[i] != pass1Pacific[i]) continue;
    for (var j = 0; j < atlantic.length; j++) {
      if (j == i) continue;
      final wouldCreateNewRepeat = repaired[j] == pass1Pacific[i];
      final swapStillBroken = repaired[i] == pass1Pacific[j];
      if (!wouldCreateNewRepeat && !swapStillBroken) {
        final temp = repaired[i];
        repaired[i] = repaired[j];
        repaired[j] = temp;
        break;
      }
    }
  }
  return repaired;
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

/// How many times [_assignRegularSeasonWeeks] will reshuffle pair order
/// and retry the whole greedy pack before giving up for real -- a bound
/// against a pathological seed looping forever, not a number expected to
/// matter in practice (see that function's own doc comment on why a
/// reshuffle should essentially always resolve a stuck pack).
const _kRegularSeasonPackAttempts = 50;

List<ScheduledGame> _assignRegularSeasonWeeks(
  List<(Team home, Team away)> pairs,
  List<Team> leagueTeams,
  Random random,
) {
  // Earliest-fit greedy packing is order-dependent -- a small fraction of
  // orderings can genuinely paint a later pair into a corner with no
  // valid (week, day) left for it, even though there's real slack overall
  // (34 team-slots for 28 games/team). Caught by a GM bug report
  // (2026-08-21) that turned out to be a pre-existing crash, not caused
  // by whatever the GM was actually doing -- it just needed the right
  // unlucky pair order to surface. Rather than let one bad order crash
  // schedule generation outright, retry with a freshly reshuffled order;
  // with this much slack, some order within a handful of attempts always
  // works.
  for (var attempt = 0; attempt < _kRegularSeasonPackAttempts; attempt++) {
    final assigned = _tryAssignRegularSeasonWeeks(pairs, leagueTeams, random);
    if (assigned != null) return assigned;
  }
  throw StateError(
    'could not pack the regular season into $_kRegularSeasonPackAttempts '
    'reshuffled attempts -- something structural is wrong (wrong team/pair '
    'counts?), not just an unlucky ordering',
  );
}

/// One greedy-pack attempt, in a freshly shuffled pair order -- `null` if
/// any pair genuinely couldn't find a slot this time (see
/// [_assignRegularSeasonWeeks]'s retry loop).
List<ScheduledGame>? _tryAssignRegularSeasonWeeks(
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

  void unbook(String abbreviation, int week, GameDay day) {
    bookedDaysByTeamAndWeek[abbreviation]?[week]?.remove(day);
  }

  // Every team plays a Continental Cup Round 1 game at this exact
  // (week, day) -- reserve it up front so the greedy pack below never
  // lands a regular-season game there too. 17 weeks x 2 days = 34
  // team-slots against 28 games/team, so losing 1 slot to the Cup still
  // leaves comfortable slack.
  for (final team in leagueTeams) {
    book(team.abbreviation, kContinentalCupRound1Week, kContinentalCupGameDay);
  }

  final assigned = <ScheduledGame>[];
  for (final (home, away) in shuffledPairs) {
    final game = _assignOneGameWeekAndDay(home, away, bookedDaysFor, book);
    if (game == null) return null;
    assigned.add(game);
  }

  // Earliest-fit above always finds *a* slot, but it finds the same
  // *earliest* one for everybody, which back-loads every team's bye days
  // onto the tail end of the season: with 34 team-slots (17 weeks x 2
  // days) against 28 games/team, the pack always finishes well before
  // week 18, so that week (and often 17 too) went completely empty for
  // the whole league instead of byes landing anywhere in between
  // (2026-08-19, a direct GM ask after watching a real season: "I don't
  // want 2 full weeks of no games backloaded, spread the off days out").
  // Smoothing it out at assignment time (e.g. preferring whichever valid
  // week is currently lightest) was tried and reverted -- it can leave a
  // *later* pair with zero valid weeks left at all, since which slots
  // stay open downstream depends on every earlier pair's choice, not
  // just this one's. Rebalancing after the fact instead only ever moves
  // a game into a slot already double-checked as open for both teams, so
  // the schedule can't regress from "valid" to "stuck" the way picking
  // slots differently up front could.
  return _spreadGamesAcrossWeeks(assigned, bookedDaysFor, book, unbook);
}

/// `null` if no (week, day) is open for both teams anywhere in the
/// regular-season window -- a real, if uncommon, outcome for this
/// particular pair order (see [_assignRegularSeasonWeeks]'s retry loop),
/// not something this function tries to recover from itself.
ScheduledGame? _assignOneGameWeekAndDay(
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
  if (assignedWeek == null) return null;

  book(home.abbreviation, assignedWeek, assignedDay!);
  book(away.abbreviation, assignedWeek, assignedDay);
  return ScheduledGame(
    week: assignedWeek,
    day: assignedDay,
    homeTeamAbbreviation: home.abbreviation,
    awayTeamAbbreviation: away.abbreviation,
    type: GameType.regularSeason,
  );
}

/// Post-processing pass over an already-valid earliest-fit regular-season
/// schedule: repeatedly finds the currently-heaviest week and, for each
/// game booked there, looks for the currently-lightest week where both
/// teams already happen to be free on one of its 2 game days -- if one
/// exists and actually helps (the target is still lighter than the
/// source once the move lands), relocates the game there instead.
///
/// Every candidate move is checked against [bookedDaysFor] before being
/// taken, the same free/busy source [_assignOneGameWeekAndDay] itself
/// trusts, so this can only ever move a game into a slot that was
/// already genuinely open for both teams -- it can smooth the calendar
/// out, but it can never invalidate it (no new double-booking, no game
/// ever leaves the regular season's week range).
List<ScheduledGame> _spreadGamesAcrossWeeks(
  List<ScheduledGame> games,
  Set<GameDay> Function(String abbreviation, int week) bookedDaysFor,
  void Function(String abbreviation, int week, GameDay day) book,
  void Function(String abbreviation, int week, GameDay day) unbook,
) {
  final byWeek = <int, int>{};
  for (final game in games) {
    byWeek[game.week] = (byWeek[game.week] ?? 0) + 1;
  }

  final result = List<ScheduledGame>.of(games);
  final weeks = [
    for (var w = kRegularSeasonStartWeek; w <= kRegularSeasonEndWeek; w++) w,
  ];

  // Bounded pass count -- each pass can only ever improve the spread (a
  // move is only taken when it strictly narrows the heaviest/lightest
  // gap), so this either converges well before the cap or the remaining
  // imbalance genuinely can't be smoothed further without violating
  // someone's booked days. Each pass re-targets the *single* currently
  // heaviest week, but tries every lighter week (lightest first) and
  // every game booked in it before giving up on that week entirely --
  // trying only the single lightest week and stopping at the first game
  // that can't move there (e.g. it's already Cup day for one side, or
  // both teams already play the lightest week's other day) used to quit
  // a whole pass over one blocked candidate, even when the very next
  // game in the same heaviest week would've moved there just fine.
  for (var pass = 0; pass < 200; pass++) {
    weeks.sort((a, b) => (byWeek[b] ?? 0).compareTo(byWeek[a] ?? 0));
    final heaviest = weeks.first;
    final lightest = weeks.last;
    if ((byWeek[heaviest] ?? 0) - (byWeek[lightest] ?? 0) <= 1) break;

    final lighterWeeks = weeks
        .where((w) => (byWeek[w] ?? 0) < (byWeek[heaviest] ?? 0) - 1)
        .toList();

    var movedThisPass = false;
    for (var i = 0; i < result.length && !movedThisPass; i++) {
      final game = result[i];
      if (game.week != heaviest) continue;

      for (final target in lighterWeeks) {
        GameDay? openDay;
        for (final day in _regularSeasonGameDays) {
          final homeFree = !bookedDaysFor(
            game.homeTeamAbbreviation,
            target,
          ).contains(day);
          final awayFree = !bookedDaysFor(
            game.awayTeamAbbreviation,
            target,
          ).contains(day);
          if (homeFree && awayFree) {
            openDay = day;
            break;
          }
        }
        if (openDay == null) continue;

        book(game.homeTeamAbbreviation, target, openDay);
        book(game.awayTeamAbbreviation, target, openDay);
        unbook(game.homeTeamAbbreviation, heaviest, game.day);
        unbook(game.awayTeamAbbreviation, heaviest, game.day);
        byWeek[heaviest] = (byWeek[heaviest] ?? 0) - 1;
        byWeek[target] = (byWeek[target] ?? 0) + 1;
        result[i] = ScheduledGame(
          week: target,
          day: openDay,
          homeTeamAbbreviation: game.homeTeamAbbreviation,
          awayTeamAbbreviation: game.awayTeamAbbreviation,
          type: GameType.regularSeason,
        );
        movedThisPass = true;
        break;
      }
    }
    if (!movedThisPass) break;
  }

  return result;
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
