import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../draft/domain/draft_prospect.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../league/domain/team.dart';
import '../../player/domain/player.dart';
import '../../player/presentation/player_card_widgets.dart';
import '../../player/presentation/trait_chip.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import '../generation/player_market_preview_generator.dart';

/// Free agents, the trade block, and this season's draft class -- one
/// screen for everywhere a GM might look to bring in a player who isn't
/// already on their roster. Reachable from the Team tab, alongside the
/// existing Bench Order/Training/Card Lab entry points.
///
/// **Free Agents is real** -- `Franchise.freeAgents`, generated once at
/// franchise creation and signable here (`CurrentFranchiseNotifier.signFreeAgent`).
/// **Trade Block and Draft both stay preview only here**: there's still
/// no trade system at all (`0B_Planned.md`'s Trade System entry), and
/// while a real draft-day flow now exists (`draft/presentation/draft_day_screen.dart`,
/// 2026-08-11, `0D_Season_2_Roadmap.md`'s "The draft, for real" stage),
/// it only ever runs once a season, right after a "Begin Next Season" --
/// this tab is for browsing a *hypothetical* class any time mid-season,
/// not the real one. Every player shown on either tab is flavor data
/// from `pickTradeBlockPreview`/`generateDraftPreview`, regenerated fresh
/// (but deterministically) every time the screen opens -- nothing on
/// either tab is tradeable or actually draftable from here, which is why
/// each still opens with a banner saying so.
class PlayerMarketScreen extends StatefulWidget {
  const PlayerMarketScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  State<PlayerMarketScreen> createState() => _PlayerMarketScreenState();
}

class _PlayerMarketScreenState extends State<PlayerMarketScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final franchise = widget.franchise;
    final seed = franchise.simulationSeed;

    final tradeBlock = pickTradeBlockPreview(
      franchise,
      Random(seed + kTradeBlockPreviewSeedOffset),
    );
    final draftClass = generateDraftPreview(
      Random(seed + kDraftPreviewSeedOffset),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Player Market')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Free Agents'),
                Tab(text: 'Trade Block'),
                Tab(text: 'Draft'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FreeAgentsTab(franchise: franchise),
                  _TradeBlockTab(franchise: franchise, picks: tradeBlock),
                  _DraftTab(franchise: franchise, prospects: draftClass),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The disclaimer every tab opens with -- see `PlayerMarketScreen`'s own
/// doc comment for why this isn't optional trim.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeAgentsTab extends ConsumerStatefulWidget {
  const _FreeAgentsTab({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_FreeAgentsTab> createState() => _FreeAgentsTabState();
}

class _FreeAgentsTabState extends ConsumerState<_FreeAgentsTab> {
  var _isSigning = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final franchise = widget.franchise;
    final activeCount = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .length;
    final hasOpenSpot = activeCount < kActiveRosterSize;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _PreviewBanner(
          text: hasOpenSpot
              ? 'Your active roster has an open spot -- sign a free agent '
                    'to fill it. Signing is instant and permanent for now; '
                    'there\'s no salary cap or contract length modeled yet.'
              : 'Your active roster is full ($activeCount/$kActiveRosterSize) '
                    '-- browse for reference, but there\'s no open spot to '
                    'sign into right now.',
        ),
        for (var i = 0; i < franchise.freeAgents.length; i++) ...[
          _PlayerMarketRow(
            franchise: franchise,
            player: franchise.freeAgents[i],
            subtitle: 'Free Agent',
            accentColor: theme.colorScheme.outline,
            jersey: null,
            trailing: hasOpenSpot
                ? FilledButton(
                    onPressed: _isSigning
                        ? null
                        : () => _sign(franchise.freeAgents[i].id),
                    child: _isSigning
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign'),
                  )
                : null,
          ),
          if (i != franchise.freeAgents.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _sign(String playerId) async {
    setState(() => _isSigning = true);
    await ref.read(currentFranchiseProvider.notifier).signFreeAgent(playerId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _TradeBlockTab extends StatelessWidget {
  const _TradeBlockTab({required this.franchise, required this.picks});

  final Franchise franchise;
  final List<({Player player, Team team})> picks;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _PreviewBanner(
          text:
              'Preview only -- there\'s no trade system yet. These are '
              'real roster players, randomly flagged as "rumored '
              'available" -- nothing here can actually be traded for.',
        ),
        for (var i = 0; i < picks.length; i++) ...[
          _PlayerMarketRow(
            franchise: franchise,
            player: picks[i].player,
            subtitle: '${picks[i].team.emoji} ${picks[i].team.name}',
            accentColor: picks[i].team.colors.primary,
            jersey: parseHexColor(picks[i].team.colors.primaryHex),
          ),
          if (i != picks.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _DraftTab extends StatelessWidget {
  const _DraftTab({required this.franchise, required this.prospects});

  final Franchise franchise;
  final List<DraftProspect> prospects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _PreviewBanner(
          text:
              'Preview only -- a fresh, hypothetical class regenerated '
              'every time this tab opens, not this season\'s real draft '
              'class. The real draft happens once the season ends -- '
              'Season Recap\'s "Begin Next Season" button leads straight '
              'into it.',
        ),
        for (var i = 0; i < prospects.length; i++) ...[
          _PlayerMarketRow(
            franchise: franchise,
            player: prospects[i].player,
            subtitle: prospects[i].college.name,
            accentColor: theme.colorScheme.primary,
            jersey: null,
          ),
          if (i != prospects.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// One player, in the same left-rail-plus-stat-chips shape the
/// production roster row ships with (`player_card_widgets.dart`) -- a GM
/// scanning this screen should recognize it as the same "player card"
/// language, not a different visual system to learn. Unlike the roster
/// row, [subtitle] replaces the archetype/age/experience line's first
/// segment with whatever identifies *why* this player is on this list
/// (their team, their college, or just "Free Agent") -- the roster row
/// doesn't need that since every one of its players is already known to
/// be on the GM's own team.
class _PlayerMarketRow extends StatelessWidget {
  const _PlayerMarketRow({
    required this.franchise,
    required this.player,
    required this.subtitle,
    required this.accentColor,
    required this.jersey,
    this.trailing,
  });

  final Franchise franchise;
  final Player player;
  final String subtitle;
  final Color accentColor;
  final RgbColor? jersey;

  /// An optional action for this row -- currently only the Free Agents
  /// tab's "Sign" button. `null` on Trade Block/Draft, which have no real
  /// action to offer yet.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhotoOvrRail(
                franchise: franchise,
                player: player,
                accentColor: accentColor,
                jersey: jersey,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${player.primaryPosition.abbreviation} '
                      '${player.name}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '$subtitle · Age ${player.age} · '
                      '${experienceLabel(player)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    StatChipRow(
                      player: player,
                      extra: [
                        StatChip(
                          label: 'POT',
                          value: player.ratings.potential,
                          color: statChipTone(context, Colors.purple),
                        ),
                      ],
                    ),
                    if (player.traits.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final trait in player.traits)
                            TraitChip(trait: trait),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
