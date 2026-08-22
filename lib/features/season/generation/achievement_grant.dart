import 'dart:math';

import '../../franchise/domain/franchise.dart';
import '../../league/domain/league.dart';
import '../../player/domain/achievement.dart';
import '../../player/domain/player.dart';
import '../../player/generation/nickname_generator.dart' as nickname_generator;
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
/// The suggested nickname is auto-applied here regardless of whose
/// player it is -- there's no nickname-review UI yet to hold it for
/// approval, so auto-applying everywhere is the honest current
/// behavior, not a design decision this function is making on its own.
/// Which of `kNicknamePools`'s 25 candidates gets suggested depends on
/// how many times [playerId] has already won [achievement] before now
/// -- read off [Player.achievements] *before* this grant appends to it,
/// so the very first win always draws candidate 0 of that player's own
/// shuffled order (see `nickname_generator.dart`'s `suggestNickname`).
///
/// [suggestNickname] (default `true`, shadowing the top-level
/// `nickname_generator.suggestNickname` this calls -- imported under
/// the `nickname_generator` prefix specifically so the two names can
/// coexist) lets a caller grant the real [Achievement] record without
/// touching [Player.nickname] at all --
/// [Achievement.allStarSelection]/[Achievement.skillsChallengeWinner]
/// pass `false` (2026-08-22, a direct GM report: "Not all all-star
/// players should get a nickname. Only the game mvp" -- every All-Star
/// weekend achievement was unconditionally overwriting whatever
/// nickname a player already had, on top of being far too easy to earn
/// for something a GM should feel was actually *earned*). A
/// merely-selected honoree or a single skills-event winner still gets
/// the real achievement (shows up in Awards, counts toward the
/// neon-hair-color unlock below), just no nickname churn from it --
/// and this function never even calls into [kNicknamePools] for either
/// of those two achievements, which don't have a pool at all
/// (`nickname_generator.dart`'s own doc comment).
///
/// If this is that player's *second* [Achievement] ever (any type), also
/// auto-assigns a random neon hair color and unlocks the neon palette
/// for them going forward -- a direct GM rule (`SeasonAwardsAnswers.md`
/// #4) superseding the portrait editor's old "unlocked on the first
/// achievement" gate (see `portrait_editor_screen.dart`'s
/// `_specialColorsUnlocked`). Untouched by [suggestNickname] -- that
/// flag is specifically about nickname churn, not about whether the
/// achievement counts at all.
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
  bool suggestNickname = true,
}) {
  Player apply(Player player) {
    var updated = player.copyWithAchievement(
      PlayerAchievementRecord(achievement: achievement, season: season),
    );
    // Only draws from [kNicknamePools] when a nickname is actually
    // wanted -- [Achievement.allStarSelection]/
    // [Achievement.skillsChallengeWinner] have no pool at all
    // (`nickname_generator.dart`'s own doc comment), so calling
    // [suggestNickname] for either would throw if this ever ran
    // unconditionally.
    if (suggestNickname) {
      final occurrenceIndex = player.achievements
          .where((record) => record.achievement == achievement)
          .length;
      updated = updated.copyWithNickname(
        nickname_generator.suggestNickname(
          achievement,
          playerId: player.id,
          occurrenceIndex: occurrenceIndex,
        ),
      );
    }
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
