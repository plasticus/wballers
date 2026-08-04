# Women's Basketball Manager — Flutter Architecture

## Current foundation

- **Project:** `womensbballmgr`
- **Android application ID:** `monster.oaf.womensbballmgr`
- **Display name:** Women's Basketball Manager
- **Targets:** Android first, web generated for the later web release.
- **Connectivity:** The game must remain usable without a network connection.

## Structure

```text
lib/
  app/                 app composition, theme, and shared preferences
  core/                cross-cutting contracts and utilities
    persistence/       local save abstractions and implementations
    ratings/           shared 1-99 rating scale used by coaches and players
    widgets/            shared, feature-agnostic UI components
  features/            user-facing feature modules
    dashboard/
    league/
      domain/            Team, Conference, TeamColors, and the initial league
    coach/
      domain/            Coach, CoachStats
    player/
      domain/            Player, PlayerRatings, Position, Handedness
    roster/
      domain/            StarTier, RosterLegality (active-roster caps)
```

Add feature modules as the game grows: `franchise_setup`, `roster`, `players`, `simulation`, `portraits`, and `game_day`. Keep their domain models and game rules free of Flutter widget imports.

## State and navigation

Use Riverpod (`flutter_riverpod`) for state management and dependency injection. `main.dart` wraps the app in a `ProviderScope`. Feature state belongs beside its feature as providers; repositories and domain/simulation logic are exposed as providers so they can be overridden in tests. Widgets render state but do not contain simulation or persistence rules. The current three-tab shell still uses local widget state because it has no game data yet — convert it as soon as a feature has real state to hold.

Use Navigator 2.0 or a routing package when deep links and nested feature flows first require it. Do not add routing complexity before the expansion-franchise flow exists.

## Local saves

`SaveRepository` (`lib/core/persistence/save_repository.dart`) is the boundary between game features and device storage: it stores and retrieves opaque strings keyed by save ID, with no knowledge of game schema.

`FileSaveRepository` (`lib/core/persistence/file_save_repository.dart`) is the current Android implementation, backed by `path_provider`'s application documents directory. Each save is one `<saveId>.json` file; writes go through a temp-file-then-rename so a crash mid-write can't corrupt a save. It's exposed to the app via `saveRepositoryProvider` (Riverpod) in `save_repository_provider.dart`. A web implementation (e.g. IndexedDB-backed) is deferred until the web build is prioritized.

`SaveEnvelope` (`lib/core/persistence/save_envelope.dart`) wraps a feature's serialized payload with a `schemaVersion` before it's handed to `SaveRepository.writeSave`. Storage itself stays schema-agnostic; migrating a payload forward from an older `schemaVersion` is the responsibility of the feature that owns that schema (starting once a real franchise save schema exists in Phase 1) — store portrait appearance data as source data there too, and cache rendered portrait PNGs separately as rebuildable, non-authoritative files.

## Design foundations

**Theme.** `AppTheme.light()` and `AppTheme.dark()` (`lib/app/app_theme.dart`) are both real, Material 3 `ColorScheme.fromSeed` themes sharing one navy/gold identity and one type-scale override. `WomensBasketballManagerApp` sets both `theme` and `darkTheme` and switches between them via `themeModeProvider` (`lib/app/app_preferences.dart`), which defaults to following the OS. A settings screen to let the coach override this is Phase 4 work; the provider it will read/write already exists.

**Text scale.** `textScaleProvider` (`lib/app/app_preferences.dart`) is a coach-controlled multiplier, independent of and combined with the OS text-size setting, applied app-wide through `MaterialApp.builder` in `lib/app/app.dart`. The pure function `resolveTextScale()` does the combining and clamps the result to `[kMinTextScale, kMaxTextScale]` so it's unit-testable without pumping a widget tree. Defaults to `1.0` (no change from the OS setting); the Phase 4 settings screen will let the coach raise it. Because this is wired now, no screen built from this point on needs its own text-scaling logic — just use normal `Text`/`TextStyle` and it inherits the ambient scale.

**Spacing.** `AppSpacing` (`lib/app/app_spacing.dart`) is a five-step scale (`xs`–`xl`, 4–32px). Use it instead of ad hoc padding/gap numbers.

**Reusable components** (`lib/core/widgets/`): `AppCard` (standard padded card surface), `LoadingView`/`EmptyStateView`/`ErrorStateView` (the three states any data-driven screen needs), and `AdPlacementPlaceholder` (see below). Build feature screens out of these rather than reinventing padding/card/state-handling per screen.

**Accessibility rules:**

- Never hardcode font sizes in a way that ignores the ambient text scale — use `Theme.of(context).textTheme.*` or a relative `TextStyle`, not a bare pixel size baked into layout math.
- Icon-only or decorative-only elements need a `Semantics` label (see `AdPlacementPlaceholder`); purely decorative animation layers (e.g. the bouncing basketball in `LoadingView`) should be wrapped in `ExcludeSemantics` so they don't produce redundant announcements.
- Empty and error states use `Semantics(liveRegion: true)` so a screen reader announces the state change without the coach having to find it manually.
- Don't rely on color alone to convey status — pair it with an icon, label, or shape (this matters for the eventual court-color-theme setting too).
- Avoid fixed-height containers around text that scales; let content grow instead of clipping at large text scales.

## Ads

`AdPlacementPlaceholder` (`lib/core/widgets/ad_placement_placeholder.dart`) reserves layout on the dashboard for a future AdMob banner, without integrating the SDK or showing production ads. Reuse it on the gameplay screen once that screen exists. The real `AdService`/AdMob adapter — test ad units in development, production units at release — is Phase 5 work, once Android app IDs and consent requirements are defined.

## Quality gates

Before each commit, run:

```powershell
dart format lib test
flutter analyze
flutter test
```
