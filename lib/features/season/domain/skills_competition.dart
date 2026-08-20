import '../../league/domain/team.dart';

/// One of the 3 events run during the All-Star break's Skills Competition
/// (2026-08-10, TODO.md item 6, a direct GM ask): originally 2 offense-only
/// events balanced by 1 defensive one, no dunk contest ("not something this
/// game can simulate meaningfully"). The 3-Point Shootout was replaced
/// 2026-08-20 with [fullPressFrenzy] (a direct GM ask, see
/// aug19pmnotes.md) -- a pure physical-ratings event, since nothing in the
/// original 3 tested [PlayerRatings.speed]/`agility`/`strength`/`stamina`
/// at all.
enum SkillsEvent { fullPressFrenzy, horse, defensiveSkillsChallenge }

extension SkillsEventLabel on SkillsEvent {
  String get label => switch (this) {
    SkillsEvent.fullPressFrenzy => 'Full Press Frenzy',
    SkillsEvent.horse => 'H-O-R-S-E',
    SkillsEvent.defensiveSkillsChallenge => 'Defensive Skills Challenge',
  };
}

/// [SkillsEvent.fullPressFrenzy]'s own tagline -- "the ultimate physical
/// challenge, driving against full court pressure from one basket to
/// another" (the GM's own wording). Deliberately not folded into [label]
/// since none of the other 2 events carry a subtitle; shown wherever the
/// result screen has room for one.
const kFullPressFrenzyDescription =
    'The ultimate physical challenge -- driving against full-court '
    'pressure from one basket to another.';

/// One participant's result in a single [SkillsEvent] -- a rating-driven
/// score with variance, not a literal shot-by-shot simulation (this
/// project's simulation depth stops at "roll a score off the relevant
/// rating," same as most other contest resolution here). Higher is always
/// better, for every event.
class SkillsEventStanding {
  const SkillsEventStanding({required this.playerId, required this.score});

  final String playerId;
  final double score;
}

/// One event's full field, [standings] sorted best-to-worst.
class SkillsEventResult {
  const SkillsEventResult({required this.event, required this.standings})
    : assert(standings.length >= 2, 'an event needs at least 2 participants');

  final SkillsEvent event;
  final List<SkillsEventStanding> standings;

  String get winnerPlayerId => standings.first.playerId;
}

/// The whole Skills Competition day's result, plus the All-Star squad
/// selection it doubles as the one persisted record of -- both
/// [SkillsEvent]s and `resolveAllStarGame` (`all_star_advancer.dart`,
/// played 3 days later on [kAllStarGameDay]) need to know who made each
/// conference's 10-player squad, and re-deriving that later from
/// then-current stats could give a different answer than what was
/// actually selected on the day (`selectConferenceAllStars` is a live
/// query, not a re-playable one) -- so it's captured once, here, and read
/// back rather than recomputed.
class SkillsCompetitionResult {
  SkillsCompetitionResult({
    required this.week,
    required this.squads,
    required this.events,
  }) : assert(
         squads.length == 2 &&
             squads[Conference.atlantic]?.length == 10 &&
             squads[Conference.pacific]?.length == 10,
         'both conferences must have exactly 10 honorees',
       );

  final int week;

  /// Each conference's 10 All-Star honorees, by [Player.id] -- *not*
  /// including the 2 filler reserves `resolveAllStarGame` adds per squad
  /// to round the sim roster out to a legal 12 (those are simulation
  /// depth only, never real honorees; see `nextBestConferencePlayers`'s
  /// own doc comment).
  final Map<Conference, List<String>> squads;

  final List<SkillsEventResult> events;
}
