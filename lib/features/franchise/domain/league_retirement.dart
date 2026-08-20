import '../../player/domain/position.dart';
import '../../player/domain/retirement_reason.dart';

/// One player's retirement off an AI team's roster, captured with real
/// name/position/team details before she's removed for good (2026-08-20,
/// a direct GM ask: "I simulated the post season, and I think my all star
/// center retired... I'd prefer to see that in an off season report, plus
/// an email from asst gm notifying of all retirements").
/// [Franchise.leagueRetirements] is where a season's own batch lives,
/// reset at every `copyWithNewSeason` the same way
/// [Franchise.skillsCompetitionResults] already is --
/// `LeagueRetirementsMailItem`/`SeasonRecapScreen`'s own retirement
/// section both read it straight (it's already scoped to the season that
/// just ended by the time either one shows it).
///
/// Deliberately AI-team-only: the GM's own roster's retirements already
/// get a proactive, actionable heads-up *before* the fact
/// (`RetirementDecisionMailItem`, resolved through the GM's own choice
/// and the coach's persuasion attempt) -- a second "she retired" mail
/// right after would just repeat news the GM was just looking at. The
/// narrative veteran's scripted retirement
/// (`resolveNarrativeVeteranRetirement`) is left out too, on purpose --
/// she gets her own dedicated in-fiction treatment (the Analyst-seat
/// swap, `match_preview_screen.dart`), and folding her into a generic
/// list here would undercut that.
class LeagueRetirement {
  const LeagueRetirement({
    required this.playerId,
    required this.name,
    required this.primaryPosition,
    required this.teamAbbreviation,
    required this.reason,
    required this.season,
  });

  final String playerId;
  final String name;
  final Position primaryPosition;

  /// The AI team she retired off of -- shown so "who retired" reads like
  /// real league news ("Alex Rivera, Chicago") rather than a bare name.
  final String teamAbbreviation;

  final RetirementReason reason;

  /// Which [Franchise.season] this retirement happened at the end of --
  /// same zero-based convention every other season-tagged record uses.
  final int season;
}
