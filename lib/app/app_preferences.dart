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
