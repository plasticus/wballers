import 'package:womensbballmgr/features/player/domain/archetype.dart';
import 'package:womensbballmgr/features/player/domain/player.dart';
import 'package:womensbballmgr/features/player/domain/player_ratings.dart';
import 'package:womensbballmgr/features/player/domain/trait.dart';

/// A player with every rating pinned to [rating], for match-engine tests
/// that need controllable, predictable inputs rather than the natural
/// spread `generatePlayer` produces.
Player testPlayer({
  required String id,
  int rating = 50,
  int heightInches = 70,
  Position position = Position.smallForward,
  Set<Trait> traits = const {},
}) {
  return Player(
    id: id,
    name: id,
    age: 25,
    yearsOfService: 3,
    hometown: 'Testville',
    primaryPosition: position,
    handedness: Handedness.right,
    biography: '',
    ratings: PlayerRatings(
      speed: rating,
      agility: rating,
      strength: rating,
      stamina: rating,
      ballControl: rating,
      passing: rating,
      interiorOffense: rating,
      perimeterOffense: rating,
      perimeterDefense: rating,
      interiorDefense: rating,
      disruption: rating,
      blocking: rating,
      potential: rating,
    ),
    heightInches: heightInches,
    archetype: kArchetypesByPosition[position]!.first,
    traits: traits,
  );
}

/// Five players sharing [label] as an id prefix and all pinned to
/// [rating] -- a full on-court lineup for possession-engine tests.
List<Player> testLineup(
  String label, {
  int rating = 50,
  Set<Trait> traits = const {},
}) {
  return List.generate(
    5,
    (i) => testPlayer(id: '$label-$i', rating: rating, traits: traits),
  );
}

/// Twelve players sharing [label] as an id prefix, with a distinct
/// descending rating per player -- a full active roster for
/// substitution/match-engine tests, with an unambiguous best-to-worst
/// ranking rather than a tie at a single flat rating.
List<Player> testRoster(String label, {int baseRating = 88, int step = 4}) {
  return List.generate(
    12,
    (i) => testPlayer(
      id: '$label-$i',
      rating: (baseRating - step * i).clamp(1, 99),
    ),
  );
}
