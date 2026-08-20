import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../portrait/presentation/portrait_editor_screen.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../season/domain/played_game_stat_line.dart';
import '../../training/domain/player_rating_field.dart';
import '../domain/achievement.dart';
import '../domain/archetype.dart';
import '../domain/player.dart';
import '../domain/player_ratings.dart';
import 'player_card_widgets.dart';
import 'trait_chip.dart';

/// Looks [playerId] up anywhere in [franchise]'s league -- the GM's own
/// roster first, then every AI team's -- rather than only the GM's own
/// roster the way this screen originally worked. (2026-08-11, TODO.md: a
/// direct GM ask to tap any player on the Stats page, not just the GM's
/// own, and land here.) Returns `null` on an id from outside this
/// playthrough's league entirely, which shouldn't happen but a "not
/// found" screen beats a crash, same posture every other id-lookup
/// fallback in this codebase already takes.
({Player player, Team team, bool isOwnRoster})? _resolvePlayer(
  Franchise franchise,
  String playerId,
) {
  for (final membership in franchise.roster) {
    if (membership.player.id == playerId) {
      return (
        player: membership.player,
        team: franchise.team,
        isOwnRoster: true,
      );
    }
  }
  for (final aiTeam in franchise.league.aiTeams) {
    for (final membership in aiTeam.roster) {
      if (membership.player.id == playerId) {
        return (
          player: membership.player,
          team: aiTeam.team,
          isOwnRoster: false,
        );
      }
    }
  }
  return null;
}

/// The hero portrait's size on this screen -- an integer multiple of the
/// 32x32 base sprite (`portraits.md`'s own render-size rule) well past the
/// 64px every list row uses elsewhere, since this is the one screen a GM
/// opens specifically to look at a single player closely (a direct GM
/// ask, 2026-08-10, `Aug9bugs.md` #18: "there should be a huge version of
/// their portrait").
const _kHeroPortraitSize = 128.0;

/// One player's full profile: ratings, traits, this season's stats, and
/// awards -- the screen `0B_Planned.md` pulled forward as an early Phase 2
/// prerequisite (spec, 2026-08-05), reachable from a roster row -- and,
/// since 2026-08-11, from any player mention on the Stats page too, own
/// roster or not (`_resolvePlayer`'s own doc comment). Drop and portrait
/// editing only ever apply to the GM's own roster -- both are hidden for
/// anyone else's player, via [_resolvePlayer]'s `isOwnRoster`.
///
/// A `ConsumerWidget` (not plain `StatelessWidget`) since the Drop action
/// (2026-08-09, a direct GM ask -- "I need a way to drop a player, so I
/// can free up a roster spot for a free agent") needs the provider to
/// actually release the player.
class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({
    required this.franchise,
    required this.playerId,
    super.key,
  });

  final Franchise franchise;
  final String playerId;

  Future<void> _confirmDrop(
    BuildContext context,
    WidgetRef ref,
    Player player,
  ) async {
    final accentColor = franchise.team.colors.primary;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drop this player?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A direct GM ask (2026-08-19): "it's gotta have an ARE YOU
            // SURE? popup with player info" -- the plain name-only prose
            // this dialog used to show made it too easy to fire off a
            // Drop without a last look at *who*, since this is the one
            // roster action with no undo (dropped players re-enter free
            // agency, but any team -- including a rebuilding rival --
            // could sign them right back out from under you).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhotoOvrRail(
                  franchise: franchise,
                  player: player,
                  accentColor: accentColor,
                  jersey: parseHexColor(franchise.team.colors.primaryHex),
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        player.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          player.primaryPosition.abbreviation,
                          if (player.jerseyNumber != null)
                            '#${player.jerseyNumber}',
                          experienceLabel(player),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      StatChipRow(player: player),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${player.name} will be released to free agency -- any team, '
              'including yours, could sign them back later.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Drop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(currentFranchiseProvider.notifier).dropPlayer(playerId);
    if (!context.mounted) return;

    // Captured before popping -- the ScaffoldMessengerState itself
    // belongs to an ancestor (the roster screen this pops back to), so it
    // stays valid, but `context` is this (about-to-be-removed) route's
    // own and shouldn't be reused for a lookup after `pop()`.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${player.name} was released to free agency.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = _resolvePlayer(franchise, playerId);
    if (resolved == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player Not Found')),
        body: const Center(child: Text('This player could not be found.')),
      );
    }
    final player = resolved.player;
    final team = resolved.team;
    final isOwnRoster = resolved.isOwnRoster;

    return Scaffold(
      appBar: AppBar(
        title: Text(player.name),
        actions: [
          if (isOwnRoster)
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Drop from Roster',
              onPressed: () => _confirmDrop(context, ref, player),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _HeaderCard(
              franchise: franchise,
              player: player,
              team: team,
              isOwnRoster: isOwnRoster,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (player.traits.isNotEmpty) ...[
              Text('Traits', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final trait in player.traits) TraitChip(trait: trait),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text('Ratings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _RatingsCard(player: player),
            const SizedBox(height: AppSpacing.lg),
            Text('This Season', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _SeasonStatsCard(franchise: franchise, playerId: playerId),
            const SizedBox(height: AppSpacing.lg),
            Text('Awards', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _AwardsCard(player: player),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Season History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppCard(
              child: Text(
                'Season-by-season history will appear here once a season '
                'can actually be completed and a new one started.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header's identity block: a hero-sized portrait, then everything
/// known about the player laid out full-width below it rather than
/// squeezed into a column beside the photo -- the same lesson the
/// production roster row already learned the hard way (`player_card_widgets.dart`'s
/// `PhotoOvrRail` doc comment: cramming a photo and a growing text column
/// into one row is what caused names to truncate and "feel dehumanizing"
/// before that redesign). With this many lines to show now (EXP,
/// handedness, secondary positions, college/country -- none of which the
/// old compact header had room for), the same mistake at a *bigger*
/// portrait size would be worse, not better.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.franchise,
    required this.player,
    required this.team,
    required this.isOwnRoster,
  });

  final Franchise franchise;
  final Player player;

  /// The team [player] actually plays for -- [franchise.team] for the
  /// GM's own roster, or whichever AI team they're really on otherwise
  /// (`_resolvePlayer`'s doc comment). Drives the portrait's accent/jersey
  /// color so an AI player's card reads as *their* team, not the GM's.
  final Team team;

  /// Portrait editing is a GM privilege over their own players only --
  /// tapping an AI player's portrait here does nothing (2026-08-11, the
  /// "any player, any team" Stats-page lookup this screen now supports).
  final bool isOwnRoster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = team.colors.primary;
    final portrait = PhotoWithJerseyBadge(
      franchise: franchise,
      player: player,
      accentColor: accentColor,
      jersey: parseHexColor(team.colors.primaryHex),
      size: _kHeroPortraitSize,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              isOwnRoster
                  ? InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PortraitEditorScreen(
                              franchise: franchise,
                              playerId: player.id,
                            ),
                          ),
                        );
                      },
                      child: portrait,
                    )
                  : portrait,
              const SizedBox(width: AppSpacing.lg),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OvrBubble(
                    overall: player.ratings.overall,
                    color: accentColor,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('OVR', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  StarTierBadge(player: player),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            player.nickname == null
                ? player.name
                : '${player.name} "${player.nickname}"',
            style: theme.textTheme.headlineSmall,
          ),
          // Only shown for someone else's player -- a GM never needs to be
          // told which team their own roster plays for, but every AI
          // player reached from the Stats page does (2026-08-11).
          if (!isOwnRoster)
            Text(
              '${team.name} (${team.abbreviation})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(text: player.primaryPosition.label),
                TextSpan(
                  text: ' (${player.archetype.label})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (player.secondaryPositions.isNotEmpty)
            Text(
              'Also plays: '
              '${player.secondaryPositions.map((p) => p.label).join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Age ${player.age} · ${formatHeightInches(player.heightInches)} '
            '· ${player.handedness == Handedness.right ? 'Right' : 'Left'}'
            '-handed · ${experienceLabel(player)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Hometown: ${player.hometown}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            player.college != null
                ? 'College: ${player.college!.name}'
                // `Player.college`'s doc comment: `null` here specifically
                // means international, and every international hometown
                // is "City, Country" -- the part after the last comma.
                : 'Country: ${player.hometown.split(', ').last}',
            style: theme.textTheme.bodySmall,
          ),
          if (player.draftRecord != null)
            Text(
              // Display is 1-based -- `PlayerDraftRecord.season`'s own
              // doc comment ("zero-based, same convention
              // PlayerAchievementRecord.season already uses") -- a direct
              // GM ask (2026-08-19): "we should see what season, round,
              // and pick they were drafted."
              'Drafted: Season ${player.draftRecord!.season + 1}, Round '
              '${player.draftRecord!.round}, Pick '
              '${player.draftRecord!.pickNumber} overall',
              style: theme.textTheme.bodySmall,
            ),
          // player.biography deliberately not shown here (2026-08-10, a
          // direct GM ask): every generated player currently gets the
          // exact same auto-generated line ("Beijing, China-born power
          // forward"), which reads as filler rather than real biography
          // text. The field itself is untouched -- still generated, just
          // not displayed -- in case real per-player biography text
          // becomes worth showing later.
        ],
      ),
    );
  }
}

class _RatingsCard extends StatelessWidget {
  const _RatingsCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RatingGroup(
            label: 'Physical',
            overall: player.ratings.physicalOverall,
            fields: kPhysicalFields,
            ratings: player.ratings,
          ),
          const Divider(height: AppSpacing.lg),
          _RatingGroup(
            label: 'Offense',
            overall: player.ratings.offenseOverall,
            fields: kOffenseFields,
            ratings: player.ratings,
          ),
          const Divider(height: AppSpacing.lg),
          _RatingGroup(
            label: 'Defense',
            overall: player.ratings.defenseOverall,
            fields: kDefenseFields,
            ratings: player.ratings,
          ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Potential',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                '${player.ratings.potential}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingGroup extends StatelessWidget {
  const _RatingGroup({
    required this.label,
    required this.overall,
    required this.fields,
    required this.ratings,
  });

  final String label;
  final int overall;
  final Set<PlayerRatingField> fields;
  final PlayerRatings ratings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            Text('$overall', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final field in fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(field.label, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  '${ratings.valueOf(field)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeasonStatsCard extends StatelessWidget {
  const _SeasonStatsCard({required this.franchise, required this.playerId});

  final Franchise franchise;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = [
      for (final played in franchise.seasonProgress.playedGames)
        ?played.boxScoreByPlayerId[playerId],
    ];

    if (lines.isEmpty) {
      return const AppCard(child: Text('No games played yet this season.'));
    }

    final gamesPlayed = lines.length;
    double total(int Function(PlayedGameStatLine) selector) =>
        lines.fold(0, (sum, line) => sum + selector(line));
    double perGame(int Function(PlayedGameStatLine) selector) =>
        total(selector) / gamesPlayed;

    final fgMade = total((l) => l.fieldGoalsMade);
    final fgAttempts = total((l) => l.fieldGoalAttempts);
    final threeMade = total((l) => l.threePointersMade);
    final threeAttempts = total((l) => l.threePointAttempts);
    final ftMade = total((l) => l.freeThrowsMade);
    final ftAttempts = total((l) => l.freeThrowAttempts);

    String pct(double made, double attempts) =>
        attempts == 0 ? '--' : '${(made / attempts * 100).round()}%';

    // One stat per line, this exact order (Points, Assists, Rebounds,
    // Blocks, Steals, Turnovers) -- the GM's own mockup (2026-08-10,
    // TODO.md item 9), replacing the old flat "7.3 PPG · 2.7 RPG · ..."
    // single-line summary. Turnovers is new here -- `PlayedGameStatLine`
    // already tracked it, nothing else on this screen showed it.
    final statLines = <(String label, double value)>[
      ('Points', perGame((l) => l.points)),
      ('Assists', perGame((l) => l.assists)),
      ('Rebounds', perGame((l) => l.totalRebounds)),
      ('Blocks', perGame((l) => l.blocks)),
      ('Steals', perGame((l) => l.steals)),
      ('Turnovers', perGame((l) => l.turnovers)),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$gamesPlayed games played', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Text('Averages per game:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final (label, value) in statLines)
            Text(
              '${value.toStringAsFixed(1)} $label',
              style: theme.textTheme.bodyLarge,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${pct(fgMade, fgAttempts)} FG · '
            '${pct(threeMade, threeAttempts)} 3PT · '
            '${pct(ftMade, ftAttempts)} FT',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AwardsCard extends StatelessWidget {
  const _AwardsCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    if (player.achievements.isEmpty) {
      return const AppCard(child: Text('No awards earned yet.'));
    }
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < player.achievements.length; i++) ...[
            Text(
              '${player.achievements[i].achievement.label} '
              '(Season ${player.achievements[i].season})',
              style: theme.textTheme.bodyLarge,
            ),
            if (i != player.achievements.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
