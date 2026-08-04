import '../../portrait/persistence/portrait_appearance_json.dart';
import '../domain/coach.dart';
import '../domain/coach_stats.dart';

Map<String, dynamic> coachStatsToJson(CoachStats stats) {
  return {
    'offense': stats.offense,
    'defense': stats.defense,
    'development': stats.development,
    'motivation': stats.motivation,
    'management': stats.management,
  };
}

CoachStats coachStatsFromJson(Map<String, dynamic> json) {
  return CoachStats(
    offense: json['offense'] as int,
    defense: json['defense'] as int,
    development: json['development'] as int,
    motivation: json['motivation'] as int,
    management: json['management'] as int,
  );
}

Map<String, dynamic> coachToJson(Coach coach) {
  return {
    'name': coach.name,
    'stats': coachStatsToJson(coach.stats),
    'appearance': coach.appearance == null
        ? null
        : portraitAppearanceToJson(coach.appearance!),
  };
}

Coach coachFromJson(Map<String, dynamic> json) {
  return Coach(
    name: json['name'] as String,
    stats: coachStatsFromJson(json['stats'] as Map<String, dynamic>),
    appearance: json['appearance'] == null
        ? null
        : portraitAppearanceFromJson(
            json['appearance'] as Map<String, dynamic>,
          ),
  );
}
