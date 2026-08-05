import 'ai_team_roster.dart';

/// This playthrough's league of AI-controlled opponents -- the 20 teams
/// `drawLeagueTeams` draws for a franchise's `simulationSeed`, minus
/// whichever one the GM's club replaced. Generated once at franchise
/// creation and persisted (`league_json.dart`), not re-derived on every
/// load -- unlike the team *identities*, a team's roster isn't a pure
/// function of the seed alone once trades/development/drafts exist, so it
/// has to be real saved state from the start.
class League {
  const League({required this.aiTeams})
    : assert(
        aiTeams.length == 19,
        'a league always has 19 AI teams -- 20 drawn, minus the GM\'s club',
      );

  final List<AiTeamRoster> aiTeams;
}
