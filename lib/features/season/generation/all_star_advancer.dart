import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../match/engine/match_engine.dart';
import '../../player/domain/achievement.dart';
import '../../player/domain/player.dart';
import '../application/franchise_rosters.dart';
import '../domain/game_result.dart';
import '../domain/league_leaders.dart';
import '../domain/played_game.dart';
import '../domain/scheduled_game.dart';
import '../domain/skills_competition.dart';
import 'achievement_grant.dart';
import 'all_star_generator.dart';

/// How many of the 20 honorees compete in each [SkillsEvent] -- a real
/// WNBA 3-point contest fields ~6-8; not every All-Star competes in every
/// event, same as the real thing. Applied independently per event (see
/// [_topByRating]'s own doc comment on why the 2 shooting events can and
/// do overlap in practice).
const _kSkillsEventFieldSize = 6;

/// The spread a [SkillsEvent] score can swing from a participant's own
/// rating, either direction -- keeps the field mostly rating-ordered
/// (the best shooter usually wins the shootout) while still leaving real
/// upset room, the same "rating plus meaningful variance" shape every
/// other contest in this engine already uses (`contest_resolver.dart`),
/// just additive instead of a win-probability curve since this is a
/// ranked field, not a single head-to-head check.
const _kSkillsScoreVariance = 20.0;

/// Resolves the All-Star break's Skills Competition day
/// ([kSkillsCompetitionDay]) -- selects both conferences' 10-player
/// squads (the one persisted record of who made the team; see
/// [SkillsCompetitionResult]'s own doc comment) and runs all 3
/// [SkillsEvent]s. Deterministic for a given [random] stream, same
/// contract as every other advance-day resolver.
SkillsCompetitionResult resolveSkillsCompetitionDay(
  Random random,
  Franchise franchise,
) {
  final leaders = computeLeagueLeaders(franchise.seasonProgress.playedGames);
  final leagueTeams = allLeagueTeams(franchise);
  final rosters = rostersByAbbreviation(franchise);

  final squadsByConference = {
    for (final conference in Conference.values)
      conference: selectConferenceAllStars(
        conference: conference,
        leagueTeams: leagueTeams,
        rostersByAbbreviation: rosters,
        leaders: leaders,
      ),
  };
  final honorees = [for (final squad in squadsByConference.values) ...squad];
  final leaguePlayers = [
    for (final team in leagueTeams) ...?rosters[team.abbreviation],
  ];

  return SkillsCompetitionResult(
    week: kAllStarWeek,
    squads: {
      for (final entry in squadsByConference.entries)
        entry.key: [for (final player in entry.value) player.id],
    },
    events: [
      _runEvent(
        random,
        SkillsEvent.fullPressFrenzy,
        // Deliberately drawn from every team in the league, not just the
        // 20 All-Star honorees [_topByRating] otherwise pulls from below --
        // the whole point of a physical-ratings event (a direct GM ask) is
        // that an elite athlete who isn't a scoring All-Star can still win
        // it, same as a real speedy role player can out-run a star in a
        // real combine drill.
        _topByRating(
          leaguePlayers,
          (p) =>
              p.ratings.speed +
              p.ratings.agility +
              p.ratings.strength +
              p.ratings.stamina,
        ),
      ),
      _runEvent(
        random,
        SkillsEvent.horse,
        _topByRating(honorees, (p) => p.ratings.perimeterOffense),
      ),
      _runEvent(
        random,
        SkillsEvent.defensiveSkillsChallenge,
        _topByRating(
          honorees,
          // The GM's own shorthand for the DPOY composite is real
          // box-score steals+blocks, but a skills-contest heat has no box
          // score to draw from -- disruption + blocking (the 2 rating
          // fields those box-score stats derive from in the first place)
          // is the closest real analog available here.
          (p) => p.ratings.disruption + p.ratings.blocking,
        ),
      ),
    ],
  );
}

/// The [_kSkillsEventFieldSize] players in [pool] ranked highest by
/// [ratingOf]. HORSE and the Defensive Skills Challenge both pass the 20
/// All-Star honorees as [pool] -- both keyed off offense/defense ratings a
/// non-honoree wouldn't plausibly beat anyway. Full Press Frenzy is the
/// exception: it passes the *whole league*, not just the honorees (see its
/// call site's own comment), since the entire point of a physical-ratings
/// event is that an elite athlete who never made an All-Star squad can
/// still win it.
List<Player> _topByRating(List<Player> pool, int Function(Player) ratingOf) {
  final ranked = [...pool]..sort((a, b) => ratingOf(b).compareTo(ratingOf(a)));
  return ranked.take(_kSkillsEventFieldSize).toList();
}

SkillsEventResult _runEvent(
  Random random,
  SkillsEvent event,
  List<Player> participants,
) {
  int ratingFor(Player player) => switch (event) {
    SkillsEvent.fullPressFrenzy =>
      player.ratings.speed +
          player.ratings.agility +
          player.ratings.strength +
          player.ratings.stamina,
    SkillsEvent.horse => player.ratings.perimeterOffense,
    SkillsEvent.defensiveSkillsChallenge =>
      player.ratings.disruption + player.ratings.blocking,
  };

  final standings = [
    for (final player in participants)
      SkillsEventStanding(
        playerId: player.id,
        score:
            ratingFor(player) +
            (random.nextDouble() - 0.5) * _kSkillsScoreVariance,
      ),
  ]..sort((a, b) => b.score.compareTo(a.score));

  return SkillsEventResult(event: event, standings: standings);
}

/// How many players [SkillsCompetitionResult.squads]' 10-per-conference
/// honoree list gets padded out to before a real match simulates --
/// `simulateMatch` requires exactly 12 (`substitution_policy.dart`).
/// [nextBestConferencePlayers] supplies the 2 extra, and they're real
/// role players in the game's box score, they just never count as
/// honorees for MVP eligibility or the "who made the team" display -- see
/// that function's own doc comment.
const _kSquadRosterSize = 12;

/// What resolving the All-Star Game itself produces: the updated
/// [Franchise] (the MVP's [Player.achievements]/[Player.nickname]/
/// portrait now reflect the award, wherever in the league they play --
/// see [_grantAllStarMvp]), the real [GameResult] for the transient
/// "show the box score" window every other game already gets,
/// [playedGame] -- the exact same lean record [GameResult] trims down to,
/// already computed here so a caller persisting it doesn't need to
/// rebuild the 2 synthetic squads just to call [PlayedGame.fromResult]
/// again -- and [mvpPlayerId] since the box score alone doesn't say who
/// won it.
class AllStarGameAdvance {
  const AllStarGameAdvance({
    required this.franchise,
    required this.result,
    required this.playedGame,
    required this.mvpPlayerId,
  });

  final Franchise franchise;
  final GameResult result;
  final PlayedGame playedGame;
  final String mvpPlayerId;
}

/// Resolves the All-Star break's Game day ([kAllStarGameDay]) -- reads
/// back the honoree squads [resolveSkillsCompetitionDay] already selected
/// and persisted (never re-derived; see [SkillsCompetitionResult]'s own
/// doc comment), pads each to a legal 12-player roster, simulates a real
/// match through the same engine every other game uses, and grants the
/// winning MVP a real [Achievement.allStarMvp]. Deterministic for a given
/// [random] stream.
///
/// Asserts a [SkillsCompetitionResult] for [kAllStarWeek] already exists
/// on [franchise] -- the Skills Competition day always resolves first
/// (`kSkillsCompetitionDay` precedes `kAllStarGameDay` within the same
/// week), so this should never fire from a normal advance-day sequence.
AllStarGameAdvance resolveAllStarGame(Random random, Franchise franchise) {
  final skillsResult = franchise.skillsCompetitionResults.firstWhere(
    (result) => result.week == kAllStarWeek,
    orElse: () => throw StateError(
      'resolveAllStarGame called before resolveSkillsCompetitionDay '
      'selected this season\'s All-Star squads',
    ),
  );

  final leaders = computeLeagueLeaders(franchise.seasonProgress.playedGames);
  final leagueTeams = allLeagueTeams(franchise);
  final rosters = rostersByAbbreviation(franchise);
  final playersById = {
    for (final roster in rosters.values)
      for (final player in roster) player.id: player,
  };

  List<Player> fullSquad(Conference conference) {
    final honoreeIds = skillsResult.squads[conference]!;
    final honorees = [for (final id in honoreeIds) playersById[id]!];
    final fillers = nextBestConferencePlayers(
      conference: conference,
      leagueTeams: leagueTeams,
      rostersByAbbreviation: rosters,
      leaders: leaders,
      excludeIds: honoreeIds.toSet(),
      count: _kSquadRosterSize - honorees.length,
    );
    return [...honorees, ...fillers];
  }

  final atlanticSquad = fullSquad(Conference.atlantic);
  final pacificSquad = fullSquad(Conference.pacific);

  final game = franchise.seasonProgress.schedule.games.firstWhere(
    (g) => g.week == kAllStarWeek && g.type == GameType.allStarGame,
  );
  final match = simulateMatch(
    random,
    homeRoster: atlanticSquad,
    awayRoster: pacificSquad,
  );
  final result = GameResult(game: game, match: match);
  final playedGame = PlayedGame.fromResult(
    result,
    rostersByAbbreviation: {
      kAtlanticAllStarsAbbreviation: atlanticSquad,
      kPacificAllStarsAbbreviation: pacificSquad,
    },
  );

  final honoreeIds = {
    ...skillsResult.squads[Conference.atlantic]!,
    ...skillsResult.squads[Conference.pacific]!,
  };
  final mvpPlayerId = allStarGameMvp(playedGame, honoreeIds: honoreeIds);

  return AllStarGameAdvance(
    franchise: _grantAllStarMvp(random, franchise, mvpPlayerId),
    result: result,
    playedGame: playedGame,
    mvpPlayerId: mvpPlayerId,
  );
}

/// The honoree (never a filler -- see [_kSquadRosterSize]'s doc comment)
/// with the highest single-game composite (points + rebounds + assists +
/// steals + blocks -- the same shape [PlayerSeasonTotals.mvpScore] uses
/// for the real MVP race, just for one game instead of a season) in
/// [playedGame]'s box score. [honoreeIds] is required rather than
/// optional so a caller can't accidentally let a squad-filler reserve win
/// the award by forgetting to pass it.
String allStarGameMvp(
  PlayedGame playedGame, {
  required Set<String> honoreeIds,
}) {
  var bestId = '';
  var bestScore = -1.0;
  for (final entry in playedGame.boxScoreByPlayerId.entries) {
    if (!honoreeIds.contains(entry.key)) continue;
    final line = entry.value;
    final score =
        line.points +
        line.totalRebounds +
        line.assists +
        line.steals +
        line.blocks;
    if (score > bestScore) {
      bestScore = score.toDouble();
      bestId = entry.key;
    }
  }
  assert(bestId.isNotEmpty, 'no honoree appeared in the All-Star box score');
  return bestId;
}

/// Grants [mvpPlayerId] a real [Achievement.allStarMvp] record via the
/// shared [applyAchievementGrant] -- see that function's own doc comment
/// for the nickname/neon-hair-unlock side effects it applies.
Franchise _grantAllStarMvp(
  Random random,
  Franchise franchise,
  String mvpPlayerId,
) {
  return applyAchievementGrant(
    random,
    franchise,
    playerId: mvpPlayerId,
    achievement: Achievement.allStarMvp,
    season: franchise.season,
  );
}
