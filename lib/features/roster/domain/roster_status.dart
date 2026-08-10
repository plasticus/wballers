import '../../player/domain/player.dart';

/// Where a player sits relative to a team's roster. See
/// `wnba_rules_reference.md` and `question.md` decision 22 for the
/// real-world rules this is loosely modeled on — loosely, because the CBA
/// mechanics that produce the real distinctions (salary cap accounting,
/// hardship-exception timing) don't exist in this game.
enum RosterStatus {
  /// Counts against the active-roster star-tier caps (`roster_legality.dart`).
  active,

  /// Exempt from the star-tier caps. Capped at [kMaxDevelopmentalRosterSpots]
  /// and restricted to players who satisfy [isDevelopmentalEligible].
  developmental,

  /// Under contract, not currently active, for any reason (injury or
  /// otherwise). Deliberately a single catch-all rather than modeling the
  /// real hardship-exception/suspended-list distinctions — doesn't count
  /// against the star-tier caps the way [active] does. [kMaxInactiveRosterSpots]
  /// caps it in the same *slot-based* sense [developmental] already had
  /// (2026-08-10, a direct GM ask for "2 Inactive slots" on the Team
  /// page) — enforced at the point a GM actually moves/signs a player
  /// into one (`current_franchise_provider.dart`'s `moveRosterStatus`/
  /// `signFreeAgent`), not retroactively via `RosterLegality`, so an
  /// already-saved roster from before this existed is never silently
  /// flagged illegal.
  reserveInactive,
}

const kMaxDevelopmentalRosterSpots = 2;

/// See [RosterStatus.reserveInactive]'s doc comment.
const kMaxInactiveRosterSpots = 2;

/// Mirrors the real 0-3-years-of-service restriction on developmental
/// contracts.
const kMaxDevelopmentalYearsOfService = 3;

bool isDevelopmentalEligible(Player player) {
  return player.yearsOfService <= kMaxDevelopmentalYearsOfService;
}

extension RosterStatusLabel on RosterStatus {
  String get label => switch (this) {
    RosterStatus.active => 'Active',
    RosterStatus.developmental => 'Developmental',
    RosterStatus.reserveInactive => 'Reserve/Inactive',
  };
}
