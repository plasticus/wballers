import 'dart:math';

import '../domain/achievement.dart';

/// Candidate nicknames the game can suggest when a player earns
/// [Achievement]. Deliberately distinct wording from `Trait`/`Archetype`
/// labels so a nickname reads as its own kind of thing in the UI, not a
/// duplicate of a rating badge or play-style tag.
const Map<Achievement, List<String>> kNicknamePools = {
  Achievement.leagueMvp: [
    'The Franchise',
    'Golden',
    'The Engine',
    'Numero Uno',
  ],
  Achievement.scoringLeader: [
    'Bucket Getter',
    'Rainmaker',
    'The Volume',
    'Point Machine',
  ],
  Achievement.defensiveMvp: [
    'The Wall',
    'Lockdown',
    'The Enforcer',
    'Iron Curtain',
  ],
  Achievement.mostDefensiveDisruptions: [
    'The Menace',
    'Chaos',
    'The Disruptor',
    'Live Wire',
  ],
};

/// Picks a random candidate nickname for [achievement]. Deterministic for
/// a given [random] stream.
String suggestNickname(Random random, Achievement achievement) {
  final pool = kNicknamePools[achievement]!;
  return pool[random.nextInt(pool.length)];
}

/// The record and a suggested nickname for earning [achievement] in
/// [season]. Deterministic for a given [random] stream.
///
/// Doesn't decide whether to auto-apply the suggested nickname or hold it
/// for GM approval -- `FLUTTER_APP_PLAN.md` splits that by team (auto for
/// the 19 AI teams, GM's choice for their own), which is a season-end
/// ceremony policy Phase 2 owns, not something this generator can decide
/// without season/team context.
({PlayerAchievementRecord record, String suggestedNickname}) grantAchievement(
  Random random, {
  required Achievement achievement,
  required int season,
}) {
  return (
    record: PlayerAchievementRecord(achievement: achievement, season: season),
    suggestedNickname: suggestNickname(random, achievement),
  );
}
