import '../../league/domain/team.dart';
import '../domain/skills_competition.dart';

Map<String, dynamic> skillsCompetitionResultToJson(
  SkillsCompetitionResult result,
) {
  return {
    'week': result.week,
    'squads': {
      for (final entry in result.squads.entries) entry.key.name: entry.value,
    },
    'events': result.events.map(_eventResultToJson).toList(),
  };
}

SkillsCompetitionResult skillsCompetitionResultFromJson(
  Map<String, dynamic> json,
) {
  final squadsJson = json['squads'] as Map<String, dynamic>;
  return SkillsCompetitionResult(
    week: json['week'] as int,
    squads: {
      for (final entry in squadsJson.entries)
        Conference.values.byName(entry.key): (entry.value as List<dynamic>)
            .map((value) => value as String)
            .toList(),
    },
    events: (json['events'] as List<dynamic>)
        .map((value) => _eventResultFromJson(value as Map<String, dynamic>))
        .toList(),
  );
}

Map<String, dynamic> _eventResultToJson(SkillsEventResult result) {
  return {
    'event': result.event.name,
    'standings': result.standings
        .map(
          (standing) => {
            'playerId': standing.playerId,
            'score': standing.score,
          },
        )
        .toList(),
  };
}

SkillsEventResult _eventResultFromJson(Map<String, dynamic> json) {
  return SkillsEventResult(
    event: SkillsEvent.values.byName(json['event'] as String),
    standings: (json['standings'] as List<dynamic>)
        .map(
          (value) => SkillsEventStanding(
            playerId: (value as Map<String, dynamic>)['playerId'] as String,
            score: (value['score'] as num).toDouble(),
          ),
        )
        .toList(),
  );
}
