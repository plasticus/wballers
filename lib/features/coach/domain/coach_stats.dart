/// A coach's stat block — deliberately much smaller than player ratings
/// (see `question.md` decision 15). Each stat is 0-100 and feeds a specific
/// later-phase system rather than being a general-purpose rating:
///
/// - [offense] / [defense]: quality of in-game tactical calls (Phase 3
///   quarter-break/timeout choices).
/// - [development]: how much this coach accelerates player growth (Phase 2
///   player development).
/// - [motivation]: team morale/chemistry management (Phase 2) and
///   close-game resilience (Phase 3).
/// - [management]: trade and draft shrewdness (Phase 2).
class CoachStats {
  const CoachStats({
    required this.offense,
    required this.defense,
    required this.development,
    required this.motivation,
    required this.management,
  }) : assert(offense >= 0 && offense <= 100, 'offense must be 0-100'),
       assert(defense >= 0 && defense <= 100, 'defense must be 0-100'),
       assert(
         development >= 0 && development <= 100,
         'development must be 0-100',
       ),
       assert(motivation >= 0 && motivation <= 100, 'motivation must be 0-100'),
       assert(management >= 0 && management <= 100, 'management must be 0-100');

  /// All stats at the midpoint — a neutral starting point before onboarding
  /// offers any real choice of coaching archetype.
  static const neutral = CoachStats(
    offense: 50,
    defense: 50,
    development: 50,
    motivation: 50,
    management: 50,
  );

  final int offense;
  final int defense;
  final int development;
  final int motivation;
  final int management;

  /// Simple unweighted average of the five stats, rounded to the nearest
  /// int, for a single-number summary (e.g. a coach list or detail header).
  int get overall {
    return ((offense + defense + development + motivation + management) / 5)
        .round();
  }
}
