import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../domain/player.dart';

/// What a [PlayerSortFilterBar] can sort a player list by -- deliberately
/// just the handful of numbers/text a GM actually scans a prospect or
/// free-agent list for (2026-08-11, a direct GM ask: "I need to be able
/// to sort by all the stuff, or filter. Like filter for position, then
/// sort by potential, that kind of thing").
enum PlayerSortKey { overall, potential, age, name }

extension PlayerSortKeyLabel on PlayerSortKey {
  String get label => switch (this) {
    PlayerSortKey.overall => 'Overall',
    PlayerSortKey.potential => 'Potential',
    PlayerSortKey.age => 'Age',
    PlayerSortKey.name => 'Name',
  };
}

/// Ascending comparison for [key] -- callers flip the sign themselves for
/// descending order (every numeric key defaults to descending -- best
/// first -- while Name defaults to ascending A-Z; see
/// [PlayerSortKey.defaultDescending]).
int comparePlayersBy(PlayerSortKey key, Player a, Player b) {
  return switch (key) {
    PlayerSortKey.overall => a.ratings.overall.compareTo(b.ratings.overall),
    PlayerSortKey.potential => a.ratings.potential.compareTo(
      b.ratings.potential,
    ),
    PlayerSortKey.age => a.age.compareTo(b.age),
    PlayerSortKey.name => a.name.compareTo(b.name),
  };
}

extension PlayerSortKeyDefaultDirection on PlayerSortKey {
  /// Whether this key should start sorted highest/latest-first. Numeric
  /// keys read best-first by default (a GM scanning by Overall or
  /// Potential wants the stars at the top); Name reads A-Z, and Age reads
  /// youngest-first (the more interesting end of a prospect/free-agent
  /// list).
  bool get defaultDescending => switch (this) {
    PlayerSortKey.overall => true,
    PlayerSortKey.potential => true,
    PlayerSortKey.age => false,
    PlayerSortKey.name => false,
  };
}

/// Sorts [items] by [sortKey]/[descending], first narrowing to
/// [position] when it isn't `null` -- the one shared implementation
/// `DraftDayScreen` and the Free Agents tab both call, so "filter for
/// position, then sort by potential" behaves identically everywhere it's
/// offered.
List<T> sortAndFilterPlayers<T>(
  List<T> items,
  Player Function(T) playerOf, {
  required Position? position,
  required PlayerSortKey sortKey,
  required bool descending,
}) {
  final filtered = position == null
      ? items
      : items.where((item) => playerOf(item).primaryPosition == position);
  final sorted = filtered.toList()
    ..sort((a, b) {
      final cmp = comparePlayersBy(sortKey, playerOf(a), playerOf(b));
      return descending ? -cmp : cmp;
    });
  return sorted;
}

/// A position filter + sort key/direction control, shared by every screen
/// that lists players a GM might want to narrow down -- currently
/// `DraftDayScreen`'s prospect list and the Player Market's Free Agents
/// tab (2026-08-11, a direct GM ask covering both). Purely
/// prop-driven/stateless: the owning screen holds the actual filter/sort
/// state and re-derives its list via [sortAndFilterPlayers] on every
/// build, the same "no cached derived state" convention the rest of this
/// codebase already follows for `Franchise`-derived UI.
class PlayerSortFilterBar extends StatelessWidget {
  const PlayerSortFilterBar({
    required this.position,
    required this.onPositionChanged,
    required this.sortKey,
    required this.descending,
    required this.onSortChanged,
    super.key,
  });

  final Position? position;
  final ValueChanged<Position?> onPositionChanged;
  final PlayerSortKey sortKey;
  final bool descending;

  /// Fired with the new sort key and its direction together -- switching
  /// keys resets to that key's own [PlayerSortKeyDefaultDirection], and
  /// tapping the direction toggle keeps the current key.
  final void Function(PlayerSortKey sortKey, bool descending) onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<Position?>(
            initialValue: position,
            decoration: const InputDecoration(
              labelText: 'Position',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              for (final p in Position.values)
                DropdownMenuItem(value: p, child: Text(p.abbreviation)),
            ],
            onChanged: onPositionChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<PlayerSortKey>(
            initialValue: sortKey,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final key in PlayerSortKey.values)
                DropdownMenuItem(value: key, child: Text(key.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                onSortChanged(value, value.defaultDescending);
              }
            },
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          icon: Icon(descending ? Icons.arrow_downward : Icons.arrow_upward),
          tooltip: descending ? 'Descending' : 'Ascending',
          onPressed: () => onSortChanged(sortKey, !descending),
        ),
      ],
    );
  }
}
