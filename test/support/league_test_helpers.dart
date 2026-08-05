import 'package:womensbballmgr/features/league/domain/league.dart';
import 'package:womensbballmgr/features/league/generation/league_generator.dart';

/// A cheap `Franchise.league` fixture for tests that need a valid League
/// but don't care about its contents -- omits portraitWeights so no
/// portrait appearances get generated for the 19 AI rosters, keeping
/// tests that don't care about portraits fast.
League testLeague({
  required int simulationSeed,
  required String replacedTeamAbbreviation,
}) {
  return generateLeague(
    simulationSeed: simulationSeed,
    replacedTeamAbbreviation: replacedTeamAbbreviation,
  );
}
