import '../../player/domain/player.dart';
import 'match_event.dart';
import 'match_result.dart';

/// One player's stat line for a single game, derived from [computeBoxScore]
/// -- never constructed or persisted directly, so there's nothing to keep
/// in sync if the derivation logic changes (same shape as
/// `StandingsEntry`/`computeStandings`).
class PlayerBoxScore {
  const PlayerBoxScore({
    required this.player,
    required this.minutesPlayed,
    required this.points,
    required this.fieldGoalsMade,
    required this.fieldGoalAttempts,
    required this.threePointersMade,
    required this.threePointAttempts,
    required this.freeThrowsMade,
    required this.freeThrowAttempts,
    required this.offensiveRebounds,
    required this.defensiveRebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.personalFouls,
  });

  final Player player;
  final double minutesPlayed;
  final int points;
  final int fieldGoalsMade;
  final int fieldGoalAttempts;
  final int threePointersMade;
  final int threePointAttempts;
  final int freeThrowsMade;
  final int freeThrowAttempts;
  final int offensiveRebounds;
  final int defensiveRebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int turnovers;
  final int personalFouls;

  int get totalRebounds => offensiveRebounds + defensiveRebounds;

  double get fieldGoalPercentage =>
      fieldGoalAttempts == 0 ? 0 : fieldGoalsMade / fieldGoalAttempts;

  double get threePointPercentage =>
      threePointAttempts == 0 ? 0 : threePointersMade / threePointAttempts;

  double get freeThrowPercentage =>
      freeThrowAttempts == 0 ? 0 : freeThrowsMade / freeThrowAttempts;
}

void _increment(Map<String, int> counts, String playerId, [int by = 1]) {
  counts[playerId] = (counts[playerId] ?? 0) + by;
}

/// Reduces [result]'s event log into a [PlayerBoxScore] per player who
/// appeared (anyone with recorded minutes) -- points, rebounds, assists,
/// steals, and blocks all come straight off the events they're named for.
/// Turnovers are gathered from every event that actually costs the
/// offense the ball: a shot-clock violation, a stolen or out-of-bounds
/// pass, or a deflected pass recovered by the other team (needs
/// [homeRoster]/[awayRoster] to tell whether a [MatchEventType.passRedirected]
/// recovery crossed team lines).
///
/// Everything internally keys off [Player.id], not the [Player] object
/// itself, even though [result]'s events and [homeRoster]/[awayRoster]
/// can be *different* object instances for the conceptually same player
/// (real bug, fixed 2026-08-10: `advanceGameDay` now auto-resolves
/// training in the same call that simulates a game day, which builds a
/// new roster with new `Player` objects for anyone whose ratings
/// changed that week -- `GameResultScreen` re-derives its roster from
/// the *post-training* franchise, while `result`'s own event log and
/// `minutesPlayed`/`personalFouls` maps were captured *pre-training*, at
/// simulation time. `Player` deliberately has no `==`/`hashCode`
/// override (this codebase always compares players by `.id`, never
/// object identity -- see `current_franchise_provider.dart`'s many
/// `.id ==` lookups), so a `Map<Player, ...>` or `List<Player>.contains`
/// call silently missed every player whose training that week actually
/// changed something -- only players training left untouched still
/// matched by chance, which is exactly the "only a handful of players,
/// minutes not summing to a full game" bug report.
List<PlayerBoxScore> computeBoxScore(
  MatchResult result, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
}) {
  final points = <String, int>{};
  final fieldGoalsMade = <String, int>{};
  final fieldGoalAttempts = <String, int>{};
  final threePointersMade = <String, int>{};
  final threePointAttempts = <String, int>{};
  final freeThrowsMade = <String, int>{};
  final freeThrowAttempts = <String, int>{};
  final offensiveRebounds = <String, int>{};
  final defensiveRebounds = <String, int>{};
  final assists = <String, int>{};
  final steals = <String, int>{};
  final blocks = <String, int>{};
  final turnovers = <String, int>{};

  final homeRosterIds = homeRoster.map((p) => p.id).toSet();

  for (final event in result.events) {
    switch (event.type) {
      case MatchEventType.shotAttempt:
        _increment(fieldGoalAttempts, event.player!.id);
        if (event.isThreePointAttempt == true) {
          _increment(threePointAttempts, event.player!.id);
        }
      case MatchEventType.shotMade:
        _increment(fieldGoalsMade, event.player!.id);
        _increment(points, event.player!.id, event.points ?? 0);
        if (event.isThreePointAttempt == true) {
          _increment(threePointersMade, event.player!.id);
        }
      case MatchEventType.freeThrowMade:
        _increment(freeThrowsMade, event.player!.id);
        _increment(freeThrowAttempts, event.player!.id);
        _increment(points, event.player!.id, event.points ?? 0);
      case MatchEventType.freeThrowMissed:
        _increment(freeThrowAttempts, event.player!.id);
      case MatchEventType.offensiveRebound:
        _increment(offensiveRebounds, event.player!.id);
      case MatchEventType.defensiveRebound:
        _increment(defensiveRebounds, event.player!.id);
      case MatchEventType.assist:
        _increment(assists, event.player!.id);
      case MatchEventType.steal:
        _increment(steals, event.player!.id);
        _increment(turnovers, event.secondPlayer!.id);
      case MatchEventType.shotBlocked:
        _increment(blocks, event.player!.id);
      case MatchEventType.shotClockViolation:
      case MatchEventType.passOutOfBounds:
        _increment(turnovers, event.player!.id);
      case MatchEventType.passRedirected:
        final recoverer = event.player!;
        final passer = event.secondPlayer;
        if (passer != null &&
            homeRosterIds.contains(passer.id) !=
                homeRosterIds.contains(recoverer.id)) {
          _increment(turnovers, passer.id);
        }
      case MatchEventType.tipOff:
      case MatchEventType.passAttempt:
      case MatchEventType.passDisrupted:
      case MatchEventType.shotMissed:
      case MatchEventType.shootingFoul:
      case MatchEventType.nonShootingFoul:
        break;
    }
  }

  final minutesPlayedById = {
    for (final entry in result.minutesPlayed.entries) entry.key.id: entry.value,
  };
  final personalFoulsById = {
    for (final entry in result.personalFouls.entries) entry.key.id: entry.value,
  };

  return [
    for (final player in [...homeRoster, ...awayRoster])
      if (minutesPlayedById.containsKey(player.id))
        PlayerBoxScore(
          player: player,
          minutesPlayed: minutesPlayedById[player.id] ?? 0,
          points: points[player.id] ?? 0,
          fieldGoalsMade: fieldGoalsMade[player.id] ?? 0,
          fieldGoalAttempts: fieldGoalAttempts[player.id] ?? 0,
          threePointersMade: threePointersMade[player.id] ?? 0,
          threePointAttempts: threePointAttempts[player.id] ?? 0,
          freeThrowsMade: freeThrowsMade[player.id] ?? 0,
          freeThrowAttempts: freeThrowAttempts[player.id] ?? 0,
          offensiveRebounds: offensiveRebounds[player.id] ?? 0,
          defensiveRebounds: defensiveRebounds[player.id] ?? 0,
          assists: assists[player.id] ?? 0,
          steals: steals[player.id] ?? 0,
          blocks: blocks[player.id] ?? 0,
          turnovers: turnovers[player.id] ?? 0,
          personalFouls: personalFoulsById[player.id] ?? 0,
        ),
  ];
}
