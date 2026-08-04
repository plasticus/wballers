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

Use built-in Flutter `ChangeNotifier`/`Listenable` state at this foundation stage. Feature state belongs beside its feature; widgets render state but do not contain simulation or persistence rules. The current three-tab shell uses local widget state only because it has no game data yet.

Use Navigator 2.0 or a routing package when deep links and nested feature flows first require it. Do not add routing complexity before the expansion-franchise flow exists.

## Local saves

`SaveRepository` is the boundary between game features and device storage. The first implementation must:

- work on Android and web;
- version save data and migrations;
- keep each franchise isolated by save ID;
- store portrait appearance data as source data and portrait PNGs as rebuildable cache;
- never require a network connection.

The initial vertical slice will add the concrete local implementation once the franchise data schema is defined.

## Ads

`AdPlacementPlaceholder` reserves dashboard layout for a future AdMob banner without integrating the SDK or showing production ads. Add the real ad adapter only after Android app IDs, test IDs, consent requirements, and an ad-free failure state are defined. Gameplay will receive a separate placement when that screen exists.

## Quality gates

Before each commit, run:

```powershell
dart format lib test
flutter analyze
flutter test
```
