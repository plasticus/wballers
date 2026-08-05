import '../../roster/domain/roster_membership.dart';
import 'team.dart';

/// One AI-controlled team's identity plus its generated roster. The GM's
/// own club isn't one of these -- see `Franchise.team`/`Franchise.roster`.
class AiTeamRoster {
  const AiTeamRoster({required this.team, required this.roster});

  final Team team;
  final List<RosterMembership> roster;
}
