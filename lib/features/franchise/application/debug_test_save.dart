import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../league/domain/league_draw.dart';
import '../../season/domain/season_progress.dart';
import '../onboarding/expansion_franchise_factory.dart';
import 'current_franchise_provider.dart';
import 'save_slots.dart';

/// How many real game days [generateNearEndOfSeasonTestSave] should leave
/// on the clock -- close enough to the postseason/off-season that a GM
/// testing that transition doesn't have to play through most of a real
/// season first, but still a couple of real games to actually watch/sim
/// before it starts (2026-08-21, a direct GM ask: "I need to develop an
/// admin save-game that fires up with like... 3 games left in the
/// season. So I can test off-season faster").
const kDebugTestSaveGameDaysRemaining = 3;

/// Always [kSaveSlotIds.last] -- a fixed "scratch" slot, deliberately
/// never the same slot ordinary onboarding defaults new GMs into
/// ([kSaveSlotIds.first]/[kCurrentFranchiseSaveId]), so mashing this
/// button in Settings can never silently overwrite a real, in-progress
/// playthrough. Whatever was in this slot before is genuinely gone once
/// this runs -- same "no confirmation needed beyond the one Settings
/// already shows" posture the rest of this dev-only tool has.
final _kDebugTestSaveSlotId = kSaveSlotIds.last;

/// Builds a fresh expansion franchise, fills its real Day-0 free-agent
/// gap, then fast-forwards it -- through the exact same [advanceGameDay]
/// every ordinary game day already uses, nothing special-cased -- until
/// [kDebugTestSaveGameDaysRemaining] real game days are left before the
/// postseason. Writes it into [_kDebugTestSaveSlotId] and makes that the
/// active slot, so the caller only needs to navigate back to the app
/// shell afterward to land right in it.
///
/// A fresh random [Team]/color/seed every call (not a fixed scenario) --
/// a GM testing the off-season repeatedly wants variety (a different
/// standings picture, a different roster) each time, not the exact same
/// rehearsed run.
Future<void> generateNearEndOfSeasonTestSave(WidgetRef ref) async {
  final random = Random();
  final seed = random.nextInt(1 << 31);
  // [replacedTeamAbbreviation] must be one of the 20 teams this exact
  // [seed] actually draws (`league_draw.dart`'s own doc comment: "which
  // teams actually exist varies game to game," drawn from a 40-team
  // design pool) -- not just any team in the wider pool, which used to
  // fail `League`'s own `aiTeams.length == 19` assertion roughly half
  // the time (2026-08-21, caught by this feature's own test going
  // genuinely flaky): the "replaced" team must have actually been drawn
  // in, or nothing ever gets filtered out of the 20-team AI side. Same
  // draw call, same seed offset (`kLeagueDrawSeedOffset`) `generateLeague`
  // itself will independently redo -- deterministic, so this really is
  // the same 20 teams `createExpansionFranchise` ends up drawing.
  final drawnTeams = drawLeagueTeams(Random(seed + kLeagueDrawSeedOffset));
  final team = drawnTeams[random.nextInt(drawnTeams.length)];
  final colors = kStarterPalettes[random.nextInt(kStarterPalettes.length)];

  await ref
      .read(activeSaveSlotProvider.notifier)
      .setActiveSlot(_kDebugTestSaveSlotId);

  final franchise = createExpansionFranchise(
    gmName: 'Test GM',
    clubName: '${team.name} (Test)',
    homeCity: team.location,
    conference: team.conference,
    replacedTeamAbbreviation: team.abbreviation,
    colors: colors,
    emoji: '🧪',
    simulationSeed: seed,
  );
  final notifier = ref.read(currentFranchiseProvider.notifier);
  await notifier.createFranchise(franchise);

  // Fill the real Day-0 gap -- same "highest-potential prospect" pick
  // `assistantGmRosterGapMessage` itself recommends, so this scratch
  // roster starts out reasonably built, not an arbitrary filler.
  final best = franchise.freeAgents.reduce(
    (a, b) => a.ratings.potential > b.ratings.potential ? a : b,
  );
  await notifier.signFreeAgent(best.id);

  // Advance for real, one day at a time, until exactly
  // [kDebugTestSaveGameDaysRemaining] game days are left -- a generous
  // guard against ever looping forever if something stalls.
  var guard = 0;
  while (guard < 200) {
    final current = ref.read(currentFranchiseProvider).value;
    if (current == null) return;
    final gameDays = gameDaysInOrder(current.seasonProgress.schedule);
    final remaining = gameDays.length - current.seasonProgress.nextGameDayIndex;
    if (remaining <= kDebugTestSaveGameDaysRemaining) return;
    final results = await notifier.advanceGameDay();
    if (results == null) return; // shouldn't happen -- fail safe, not loud
    guard++;
  }
}
