import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';

/// A player whose twelve stored ratings are all [overall], so
/// `ratings.overall` equals exactly [overall] (their unweighted average).
Player playerWithOverall(int overall, {String name = 'Test Player'}) {
  return Player(
    name: name,
    age: 24,
    hometown: 'Fictional City',
    primaryPosition: Position.pointGuard,
    handedness: Handedness.right,
    biography: '',
    ratings: PlayerRatings(
      speed: overall,
      agility: overall,
      strength: overall,
      stamina: overall,
      ballControl: overall,
      passing: overall,
      interiorOffense: overall,
      perimeterOffense: overall,
      perimeterDefense: overall,
      interiorDefense: overall,
      disruption: overall,
      blocking: overall,
      potential: overall,
    ),
  );
}
