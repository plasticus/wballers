import '../../portrait/persistence/portrait_appearance_json.dart';
import '../domain/achievement.dart';
import '../domain/archetype.dart';
import '../domain/player.dart';
import '../domain/player_ratings.dart';
import '../domain/trait.dart';

Map<String, dynamic> playerAchievementRecordToJson(
  PlayerAchievementRecord record,
) {
  return {'achievement': record.achievement.name, 'season': record.season};
}

PlayerAchievementRecord playerAchievementRecordFromJson(
  Map<String, dynamic> json,
) {
  return PlayerAchievementRecord(
    achievement: Achievement.values.byName(json['achievement'] as String),
    season: json['season'] as int,
  );
}

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
    'archetype': player.archetype.name,
    'traits': player.traits.map((trait) => trait.name).toList(),
    'appearance': player.appearance == null
        ? null
        : portraitAppearanceToJson(player.appearance!),
    'achievements': player.achievements
        .map(playerAchievementRecordToJson)
        .toList(),
    'nickname': player.nickname,
  };
}

Player playerFromJson(Map<String, dynamic> json) {
  final primaryPosition = Position.values.byName(
    json['primaryPosition'] as String,
  );

  return Player(
    id: json['id'] as String,
    name: json['name'] as String,
    age: json['age'] as int,
    yearsOfService: json['yearsOfService'] as int,
    hometown: json['hometown'] as String,
    primaryPosition: primaryPosition,
    secondaryPositions: (json['secondaryPositions'] as List<dynamic>)
        .map((value) => Position.values.byName(value as String))
        .toSet(),
    handedness: Handedness.values.byName(json['handedness'] as String),
    biography: json['biography'] as String,
    ratings: playerRatingsFromJson(json['ratings'] as Map<String, dynamic>),
    // A save from before question.md decision 27 has neither key -- fall
    // back to a legal default rather than failing to load entirely.
    archetype: json['archetype'] == null
        ? kArchetypesByPosition[primaryPosition]!.first
        : Archetype.values.byName(json['archetype'] as String),
    traits: (json['traits'] as List<dynamic>? ?? const [])
        .map((value) => Trait.values.byName(value as String))
        .toSet(),
    appearance: json['appearance'] == null
        ? null
        : portraitAppearanceFromJson(
            json['appearance'] as Map<String, dynamic>,
          ),
    achievements: (json['achievements'] as List<dynamic>? ?? const [])
        .map(
          (value) =>
              playerAchievementRecordFromJson(value as Map<String, dynamic>),
        )
        .toList(),
    nickname: json['nickname'] as String?,
  );
}
