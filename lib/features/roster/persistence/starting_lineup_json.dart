import '../../player/domain/player.dart';
import '../domain/starting_lineup.dart';

Map<String, dynamic> startingLineupToJson(StartingLineup lineup) {
  return {
    'startersByPosition': lineup.startersByPosition.map(
      (position, playerId) => MapEntry(position.name, playerId),
    ),
  };
}

StartingLineup startingLineupFromJson(Map<String, dynamic> json) {
  final raw = json['startersByPosition'] as Map<String, dynamic>;
  return StartingLineup(
    startersByPosition: raw.map(
      (positionName, playerId) =>
          MapEntry(Position.values.byName(positionName), playerId as String),
    ),
  );
}
