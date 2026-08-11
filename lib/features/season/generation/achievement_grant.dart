import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/league.dart';
import '../../player/domain/achievement.dart';
import '../../player/domain/player.dart';
import '../../player/generation/nickname_generator.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_membership.dart';

/// Grants [playerId] a real [Achievement] and applies every side effect
/// that comes with it, wherever they actually play -- the GM's own
/// roster or any of the 19 AI teams, since a league-wide award can land
/// on either. Shared by every award resolver (`all_star_advancer.dart`'s
/// `resolveAllStarGame`, `season_awards_advancer.dart`'s
/// `resolveSeasonAwards`) so this "find the player, apply the grant"
/// logic exists exactly once rather than once per award type.
///
/// The suggested nickname (`grantAchievement`'s own doc comment flags
/// this as an eventual GM-approval split for their own roster) is
/// auto-applied here regardless of whose player it is -- there's no
/// nickname-review UI yet to hold it for approval, so auto-applying
/// everywhere is the honest current behavior, not a design decision
/// this function is making on its own.
///
/// If this is that player's *second* [Achievement] ever (any type), also
/// auto-assigns a random neon hair color and unlocks the neon palette
/// for them going forward -- a direct GM rule (`SeasonAwardsAnswers.md`
/// #4) superseding the portrait editor's old "unlocked on the first
/// achievement" gate (see `portrait_editor_screen.dart`'s
/// `_specialColorsUnlocked`).
///
/// A no-op if [playerId] isn't found on any roster at all (never
/// expected in practice -- every caller resolves awards against players
/// still on a roster, before any retirement/roster-legality pass could
/// remove them), same lenient posture this logic always had.
Franchise applyAchievementGrant(
  Random random,
  Franchise franchise, {
  required String playerId,
  required Achievement achievement,
  required int season,
}) {
  final grant = grantAchievement(
    random,
    achievement: achievement,
    season: season,
  );

  Player apply(Player player) {
    var updated = player
        .copyWithAchievement(grant.record)
        .copyWithNickname(grant.suggestedNickname);
    final appearance = updated.appearance;
    if (updated.achievements.length >= 2 && appearance != null) {
      final neonKeys = kNeonHairColors.keys.toList();
      final color = neonKeys[random.nextInt(neonKeys.length)];
      updated = updated.copyWithAppearance(
        appearance.copyWith(topHairColor: color),
      );
    }
    return updated;
  }

  if (franchise.roster.any((m) => m.player.id == playerId)) {
    return franchise.copyWithRoster([
      for (final membership in franchise.roster)
        if (membership.player.id == playerId)
          RosterMembership(
            player: apply(membership.player),
            status: membership.status,
          )
        else
          membership,
    ]);
  }

  return franchise.copyWithLeague(
    League(
      aiTeams: [
        for (final aiTeam in franchise.league.aiTeams)
          if (aiTeam.roster.any((m) => m.player.id == playerId))
            aiTeam.copyWithRoster([
              for (final membership in aiTeam.roster)
                if (membership.player.id == playerId)
                  RosterMembership(
                    player: apply(membership.player),
                    status: membership.status,
                  )
                else
                  membership,
            ])
          else
            aiTeam,
      ],
    ),
  );
}
