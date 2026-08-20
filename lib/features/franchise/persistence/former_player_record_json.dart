import '../../player/domain/position.dart';
import '../domain/former_player_record.dart';

Map<String, dynamic> formerPlayerRecordToJson(FormerPlayerRecord record) {
  return {
    'playerId': record.playerId,
    'name': record.name,
    'primaryPosition': record.primaryPosition.name,
    'jerseyNumber': record.jerseyNumber,
  };
}

FormerPlayerRecord formerPlayerRecordFromJson(Map<String, dynamic> json) {
  return FormerPlayerRecord(
    playerId: json['playerId'] as String,
    name: json['name'] as String,
    primaryPosition: Position.values.byName(
      json['primaryPosition'] as String,
    ),
    jerseyNumber: json['jerseyNumber'] as int?,
  );
}
