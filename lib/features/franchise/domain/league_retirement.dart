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
/// Originally AI-team-only, on the reasoning that the GM's own roster's
/// retirements already got a proactive, actionable heads-up *before* the
/// fact (`RetirementDecisionMailItem`) -- a second "she retired" mail
/// right after would just repeat news the GM was just looking at. A
/// direct GM report (2026-08-22) found that reasoning didn't hold in
/// practice: "Couldn't tell if my star player retired. I skimmed the end
/// season report a little too fast" -- the *decision* mail is easy to
/// skim past, especially since acting on it takes a real choice
/// (persuade or let go), and the actual outcome doesn't always register.
/// [teamAbbreviation] can be the GM's own team now too --
/// `current_franchise_provider.dart`'s `_retirePlayer` appends one the
/// instant a real retirement resolves, same list AI-team retirements
/// already land in (`copyWithLeagueRetirements`). Consumers that meant
/// "AI-only" specifically (`LeagueRetirementsMailItem`, still that in
/// intent) filter this list down themselves rather than the type
/// enforcing it -- `SeasonRecapScreen`'s "League Retirements" section
/// deliberately stays unfiltered, since the GM's own retiree showing up
/// there too is exactly the visibility this report asked for. The
/// narrative veteran's scripted retirement
/// (`resolveNarrativeVeteranRetirement`) is left out of this list either
/// way, on purpose -- she gets her own dedicated in-fiction treatment
/// (the Analyst-seat swap, `match_preview_screen.dart`), and folding her
/// into a generic list here would undercut that.
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
