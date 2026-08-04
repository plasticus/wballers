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
  app/                 app composition and theme
  core/                cross-cutting contracts and utilities
    persistence/       local save abstractions and implementations
  features/            user-facing feature modules
    dashboard/
```

Add feature modules as the game grows: `franchise_setup`, `roster`, `players`, `league`, `simulation`, `portraits`, and `game_day`. Keep their domain models and game rules free of Flutter widget imports.

## State and navigation

Use Riverpod (`flutter_riverpod`) for state management and dependency injection. `main.dart` wraps the app in a `ProviderScope`. Feature state belongs beside its feature as providers; repositories and domain/simulation logic are exposed as providers so they can be overridden in tests. Widgets render state but do not contain simulation or persistence rules. The current three-tab shell still uses local widget state because it has no game data yet — convert it as soon as a feature has real state to hold.

Use Navigator 2.0 or a routing package when deep links and nested feature flows first require it. Do not add routing complexity before the expansion-franchise flow exists.

## Local saves

`SaveRepository` (`lib/core/persistence/save_repository.dart`) is the boundary between game features and device storage: it stores and retrieves opaque strings keyed by save ID, with no knowledge of game schema.

`FileSaveRepository` (`lib/core/persistence/file_save_repository.dart`) is the current Android implementation, backed by `path_provider`'s application documents directory. Each save is one `<saveId>.json` file; writes go through a temp-file-then-rename so a crash mid-write can't corrupt a save. It's exposed to the app via `saveRepositoryProvider` (Riverpod) in `save_repository_provider.dart`. A web implementation (e.g. IndexedDB-backed) is deferred until the web build is prioritized.

`SaveEnvelope` (`lib/core/persistence/save_envelope.dart`) wraps a feature's serialized payload with a `schemaVersion` before it's handed to `SaveRepository.writeSave`. Storage itself stays schema-agnostic; migrating a payload forward from an older `schemaVersion` is the responsibility of the feature that owns that schema (starting once a real franchise save schema exists in Phase 1) — store portrait appearance data as source data there too, and cache rendered portrait PNGs separately as rebuildable, non-authoritative files.

## Ads

`AdPlacementPlaceholder` reserves dashboard layout for a future AdMob banner without integrating the SDK or showing production ads. Add the real ad adapter only after Android app IDs, test IDs, consent requirements, and an ad-free failure state are defined. Gameplay will receive a separate placement when that screen exists.

## Quality gates

Before each commit, run:

```powershell
dart format lib test
flutter analyze
flutter test
```
