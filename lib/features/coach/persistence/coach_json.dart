import '../../portrait/persistence/portrait_appearance_json.dart';
import '../domain/coach.dart';
import '../domain/coach_archetype.dart';
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
    'archetype': coach.archetype.name,
    'age': coach.age,
    'appearance': coach.appearance == null
        ? null
        : portraitAppearanceToJson(coach.appearance!),
    'seasonsAsHeadCoach': coach.seasonsAsHeadCoach,
    'careerWins': coach.careerWins,
    'careerLosses': coach.careerLosses,
    'championshipsWon': coach.championshipsWon,
  };
}

Coach coachFromJson(Map<String, dynamic> json) {
  return Coach(
    name: json['name'] as String,
    stats: coachStatsFromJson(json['stats'] as Map<String, dynamic>),
    // No legacy-save fallback -- pre-release schema churn gets a fresh
    // save, not defensive parsing (0C_Vision_and_Ideas.md).
    archetype: CoachArchetype.values.byName(json['archetype'] as String),
    age: json['age'] as int,
    appearance: json['appearance'] == null
        ? null
        : portraitAppearanceFromJson(
            json['appearance'] as Map<String, dynamic>,
          ),
    seasonsAsHeadCoach: json['seasonsAsHeadCoach'] as int,
    careerWins: json['careerWins'] as int,
    careerLosses: json['careerLosses'] as int,
    championshipsWon: json['championshipsWon'] as int,
  );
}
