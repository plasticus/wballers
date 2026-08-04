import '../domain/player.dart';
import '../domain/player_ratings.dart';

Map<String, dynamic> playerRatingsToJson(PlayerRatings ratings) {
  return {
    'speed': ratings.speed,
    'agility': ratings.agility,
    'strength': ratings.strength,
    'stamina': ratings.stamina,
    'ballControl': ratings.ballControl,
    'passing': ratings.passing,
    'interiorOffense': ratings.interiorOffense,
    'perimeterOffense': ratings.perimeterOffense,
    'perimeterDefense': ratings.perimeterDefense,
    'interiorDefense': ratings.interiorDefense,
    'disruption': ratings.disruption,
    'blocking': ratings.blocking,
    'potential': ratings.potential,
  };
}

PlayerRatings playerRatingsFromJson(Map<String, dynamic> json) {
  return PlayerRatings(
    speed: json['speed'] as int,
    agility: json['agility'] as int,
    strength: json['strength'] as int,
    stamina: json['stamina'] as int,
    ballControl: json['ballControl'] as int,
    passing: json['passing'] as int,
    interiorOffense: json['interiorOffense'] as int,
    perimeterOffense: json['perimeterOffense'] as int,
    perimeterDefense: json['perimeterDefense'] as int,
    interiorDefense: json['interiorDefense'] as int,
    disruption: json['disruption'] as int,
    blocking: json['blocking'] as int,
    potential: json['potential'] as int,
  );
}

Map<String, dynamic> playerToJson(Player player) {
  return {
    'id': player.id,
    'name': player.name,
    'age': player.age,
    'yearsOfService': player.yearsOfService,
    'hometown': player.hometown,
    'primaryPosition': player.primaryPosition.name,
    'secondaryPositions': player.secondaryPositions
        .map((position) => position.name)
        .toList(),
    'handedness': player.handedness.name,
    'biography': player.biography,
    'ratings': playerRatingsToJson(player.ratings),
  };
}

Player playerFromJson(Map<String, dynamic> json) {
  return Player(
    id: json['id'] as String,
    name: json['name'] as String,
    age: json['age'] as int,
    yearsOfService: json['yearsOfService'] as int,
    hometown: json['hometown'] as String,
    primaryPosition: Position.values.byName(json['primaryPosition'] as String),
    secondaryPositions: (json['secondaryPositions'] as List<dynamic>)
        .map((value) => Position.values.byName(value as String))
        .toSet(),
    handedness: Handedness.values.byName(json['handedness'] as String),
    biography: json['biography'] as String,
    ratings: playerRatingsFromJson(json['ratings'] as Map<String, dynamic>),
  );
}
