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

void _increment(Map<Player, int> counts, Player player, [int by = 1]) {
  counts[player] = (counts[player] ?? 0) + by;
}

/// Reduces [result]'s event log into a [PlayerBoxScore] per player who
/// appeared (anyone with recorded minutes) -- points, rebounds, assists,
/// steals, and blocks all come straight off the events they're named for.
/// Turnovers are gathered from every event that actually costs the
/// offense the ball: a shot-clock violation, a stolen or out-of-bounds
/// pass, or a deflected pass recovered by the other team (needs
/// [homeRoster]/[awayRoster] to tell whether a [MatchEventType.passRedirected]
/// recovery crossed team lines).
List<PlayerBoxScore> computeBoxScore(
  MatchResult result, {
  required List<Player> homeRoster,
  required List<Player> awayRoster,
}) {
  final points = <Player, int>{};
  final fieldGoalsMade = <Player, int>{};
  final fieldGoalAttempts = <Player, int>{};
  final threePointersMade = <Player, int>{};
  final threePointAttempts = <Player, int>{};
  final freeThrowsMade = <Player, int>{};
  final freeThrowAttempts = <Player, int>{};
  final offensiveRebounds = <Player, int>{};
  final defensiveRebounds = <Player, int>{};
  final assists = <Player, int>{};
  final steals = <Player, int>{};
  final blocks = <Player, int>{};
  final turnovers = <Player, int>{};

  for (final event in result.events) {
    switch (event.type) {
      case MatchEventType.shotAttempt:
        _increment(fieldGoalAttempts, event.player!);
        if (event.isThreePointAttempt == true) {
          _increment(threePointAttempts, event.player!);
        }
      case MatchEventType.shotMade:
        _increment(fieldGoalsMade, event.player!);
        _increment(points, event.player!, event.points ?? 0);
        if (event.isThreePointAttempt == true) {
          _increment(threePointersMade, event.player!);
        }
      case MatchEventType.freeThrowMade:
        _increment(freeThrowsMade, event.player!);
        _increment(freeThrowAttempts, event.player!);
        _increment(points, event.player!, event.points ?? 0);
      case MatchEventType.freeThrowMissed:
        _increment(freeThrowAttempts, event.player!);
      case MatchEventType.offensiveRebound:
        _increment(offensiveRebounds, event.player!);
      case MatchEventType.defensiveRebound:
        _increment(defensiveRebounds, event.player!);
      case MatchEventType.assist:
        _increment(assists, event.player!);
      case MatchEventType.steal:
        _increment(steals, event.player!);
        _increment(turnovers, event.secondPlayer!);
      case MatchEventType.shotBlocked:
        _increment(blocks, event.player!);
      case MatchEventType.shotClockViolation:
      case MatchEventType.passOutOfBounds:
        _increment(turnovers, event.player!);
      case MatchEventType.passRedirected:
        final recoverer = event.player!;
        final passer = event.secondPlayer;
        if (passer != null &&
            homeRoster.contains(passer) != homeRoster.contains(recoverer)) {
          _increment(turnovers, passer);
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

  return [
    for (final player in [...homeRoster, ...awayRoster])
      if (result.minutesPlayed.containsKey(player))
        PlayerBoxScore(
          player: player,
          minutesPlayed: result.minutesPlayed[player] ?? 0,
          points: points[player] ?? 0,
          fieldGoalsMade: fieldGoalsMade[player] ?? 0,
          fieldGoalAttempts: fieldGoalAttempts[player] ?? 0,
          threePointersMade: threePointersMade[player] ?? 0,
          threePointAttempts: threePointAttempts[player] ?? 0,
          freeThrowsMade: freeThrowsMade[player] ?? 0,
          freeThrowAttempts: freeThrowAttempts[player] ?? 0,
          offensiveRebounds: offensiveRebounds[player] ?? 0,
          defensiveRebounds: defensiveRebounds[player] ?? 0,
          assists: assists[player] ?? 0,
          steals: steals[player] ?? 0,
          blocks: blocks[player] ?? 0,
          turnovers: turnovers[player] ?? 0,
          personalFouls: result.personalFouls[player] ?? 0,
        ),
  ];
}
