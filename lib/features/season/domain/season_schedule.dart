import 'scheduled_game.dart';

/// The full slate of games generated for one season -- see
/// `generateSeasonSchedule`. Only what can be determined ahead of time is
/// included: the preseason, the full regular season, and the Continental
/// Cup's Round 1 (a straight random draw, per `0B_Planned.md`).
/// Continental Cup Rounds 2-5 depend on earlier rounds' results, so they
/// aren't part of the initial schedule -- they get appended once a
/// result-producing simulator exists.
class SeasonSchedule {
  const SeasonSchedule({required this.games});

  final List<ScheduledGame> games;
}
