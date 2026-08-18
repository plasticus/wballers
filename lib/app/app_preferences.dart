import 'package:flutter_riverpod/legacy.dart';

/// Bounds for the combined (system × in-app) text scale. Generous on the
/// upper end since some players need noticeably larger text than the OS
/// default provides; still clamped so layouts don't break entirely.
const kMinTextScale = 0.85;
const kMaxTextScale = 2.2;

/// The coach's in-app text-size preference, independent of the OS setting.
/// Defaults to 1.0 (no adjustment). A future settings screen (Phase 4)
/// will read and write this; nothing else needs to change when it lands.
final textScaleProvider = StateProvider<double>((ref) => 1.0);

/// The coach's light/dark preference. Defaults to following the OS.
final themeModeProvider = StateProvider((ref) => ThemeModePreference.system);

enum ThemeModePreference { system, light, dark }

/// Watch Live vs. Sim Instantly's last-used value (2026-08-18, `TODO.md`
/// item 8's live-game architecture stage 5, a direct GM ask: "should be
/// set at whatever you did last time") -- `MatchPreviewScreen`'s toggle
/// reads and writes this instead of keeping its own local `State`, so
/// flipping it off for one game keeps it off for the next without the GM
/// having to redo it every time. Same in-memory-only, session-scoped
/// persistence tier as [textScaleProvider]/[themeModeProvider] above (no
/// disk persistence exists for any preference in this app yet) --
/// defaults back to on (the feature's whole point) at the next app
/// launch, not remembered forever.
final watchLiveProvider = StateProvider<bool>((ref) => true);

/// Combines the OS text-scale setting with the coach's in-app multiplier,
/// then clamps the result. [systemScale] should come from
/// `MediaQuery.textScalerOf(context).scale(1.0)`, which approximates a
/// possibly non-linear system scaler as a single multiplier — good enough
/// for a multiplier we apply on top of it, not exact fidelity.
double resolveTextScale({
  required double systemScale,
  required double userMultiplier,
}) {
  return (systemScale * userMultiplier).clamp(kMinTextScale, kMaxTextScale);
}
