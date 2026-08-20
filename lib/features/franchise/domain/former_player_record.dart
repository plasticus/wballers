import '../../player/domain/position.dart';

/// A lightweight snapshot of a GM-own-roster player's name/position/jersey,
/// captured the moment she actually retires (`current_franchise_provider.dart`'s
/// `_retirePlayer`) -- a direct GM report (2026-08-19): "I simulated the
/// post season, and I think my all star center retired... in the post
/// season report, my all star... shows on the report as 'Former Player.'"
///
/// Retiring removes a player from [Franchise.roster] entirely (same
/// "retired means retired, not signable" rule `resolveAiTeamRetirements`
/// already established for AI teams), but this season's own Player
/// Development results (`Franchise.trainingReports`/
/// `Franchise.seasonEndAgingResults`) still reference her by
/// [Player.id] alone -- once she's gone from [Franchise.roster], nothing
/// could resolve that id back to a real name, so every report simply
/// showed the generic "Former Player" fallback instead
/// (`training_report_screen.dart`/`season_to_date_report_screen.dart`/
/// `season_recap_screen.dart`'s own `_playerLabel`, all 3 kept in sync by
/// hand). [Franchise.formerPlayers] is where that name survives instead.
///
/// Deliberately GM-roster-only, not a league-wide "every retired player
/// ever" registry -- [_playerLabel] only ever looks up ids that could
/// appear in the GM's own [Franchise.trainingReports]/
/// [Franchise.seasonEndAgingResults], which only ever contain the GM's
/// own roster's players (training has no AI-team equivalent report). An
/// AI team's retiree, or a player the GM simply dropped (routed to
/// [Franchise.freeAgents], not retired -- her data survives there
/// already), never needs this.
class FormerPlayerRecord {
  const FormerPlayerRecord({
    required this.playerId,
    required this.name,
    required this.primaryPosition,
    this.jerseyNumber,
  });

  final String playerId;
  final String name;
  final Position primaryPosition;
  final int? jerseyNumber;

  /// The exact `'${primaryPosition.abbreviation} #N Name'` format every
  /// `_playerLabel` implementation already used for a live roster player
  /// -- a retired player's label should read identically, not visibly
  /// different just because she's gone.
  String get label {
    final jersey = jerseyNumber != null ? '#$jerseyNumber ' : '';
    return '${primaryPosition.abbreviation} $jersey$name';
  }
}
