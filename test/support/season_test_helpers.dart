import 'dart:math';

import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/league/generation/league_generator.dart';
import 'package:womensbballmgr/features/season/domain/season_progress.dart';
import 'package:womensbballmgr/features/season/generation/season_schedule_generator.dart';

/// A cheap `Franchise.seasonProgress` fixture for tests that need a valid
/// schedule but don't care about its contents -- mirrors exactly what
/// `createExpansionFranchise` builds (the 19 AI teams plus [ownTeam],
/// scheduled from a seed-derived stream), just without needing a whole
/// `Franchise` to already exist first.
SeasonProgress testSeasonProgress({
  required int simulationSeed,
  required String replacedTeamAbbreviation,
  required Team ownTeam,
}) {
  final league = generateLeague(
    simulationSeed: simulationSeed,
    replacedTeamAbbreviation: replacedTeamAbbreviation,
  );
  final scheduleTeams = [
    ...league.aiTeams.map((aiTeam) => aiTeam.team),
    ownTeam,
  ];
  final schedule = generateSeasonSchedule(
    scheduleTeams,
    Random(simulationSeed + kSeasonScheduleSeedOffset),
  );
  return SeasonProgress(
    schedule: schedule,
    playedGames: const [],
    nextWeek: kPreseasonWeek,
  );
}
