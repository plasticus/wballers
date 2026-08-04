import 'coach_stats.dart';

/// The coach — the player's persona in the game. One per franchise.
///
/// Portrait appearance isn't linked here yet: the portrait system (see
/// `portraits.md`) already models coaches as a distinct entity, but the
/// Flutter asset pipeline that would back a `portraitAppearance` field here
/// is Phase 1.5 work.
class Coach {
  const Coach({required this.name, required this.stats});

  final String name;
  final CoachStats stats;
}
