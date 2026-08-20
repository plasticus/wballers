import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../draft/domain/draft_prospect.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/player.dart';
import '../../player/presentation/player_card_widgets.dart';
import '../../player/presentation/player_detail_screen.dart';
import '../../player/presentation/player_sort_filter_bar.dart';
import '../../player/presentation/trait_chip.dart';
import '../../portrait/rendering/portrait_colors.dart';
import '../../roster/domain/roster_legality.dart';
import '../../roster/domain/roster_status.dart';
import '../../trade/domain/pick_ownership.dart';
import '../../trade/domain/trade_asset.dart';
import '../../trade/domain/trade_offer.dart';
import '../../trade/domain/trade_window.dart';
import '../../trade/generation/trade_offer_generator.dart';
import '../generation/player_market_preview_generator.dart';

/// Free agents, the Trade Board, and this season's draft class -- one
/// screen for everywhere a GM might look to bring in a player who isn't
/// already on their roster. Reachable from the Team tab, alongside the
/// existing Bench Order/Training/Card Lab entry points.
///
/// **Free Agents is real** -- `Franchise.freeAgents`, generated once at
/// franchise creation and signable here (`CurrentFranchiseNotifier.signFreeAgent`).
/// **Trade Board is real too** (`trading-and-hidden-gems-notes.md`): up
/// to 5 live AI offers at a time, regenerated deterministically off the
/// current game day (`generateTradeOffers`), accept-or-decline only --
/// no player-initiated trades, no negotiating. Only open from right
/// after the draft through the trade window (`isTradeWindowOpen`).
/// **Draft stays preview only**: while a real draft-day flow now exists
/// (`draft/presentation/draft_day_screen.dart`, 2026-08-11,
/// `0D_Season_2_Roadmap.md`'s "The draft, for real" stage), it only ever
/// runs once a season, right after a "Begin Next Season" -- this tab is
/// for browsing a *hypothetical* class any time mid-season, not the real
/// one. Every player shown there is flavor data from
/// `generateDraftPreview`, regenerated fresh (but deterministically)
/// every time the screen opens -- nothing on it is actually draftable
/// from here, which is why it still opens with a banner saying so.
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
                Tab(text: 'Trade Board'),
                Tab(text: 'Draft'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FreeAgentsTab(franchise: franchise),
                  _TradeBoardTab(franchise: franchise),
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
  Position? _position;
  var _sortKey = PlayerSortKey.overall;
  var _descending = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final franchise = widget.franchise;
    final activeCount = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .length;
    final hasOpenSpot = activeCount < kActiveRosterSize;
    final freeAgents = sortAndFilterPlayers(
      franchise.freeAgents,
      (player) => player,
      position: _position,
      sortKey: _sortKey,
      descending: _descending,
    );

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
        PlayerSortFilterBar(
          position: _position,
          onPositionChanged: (value) => setState(() => _position = value),
          sortKey: _sortKey,
          descending: _descending,
          onSortChanged: (key, descending) => setState(() {
            _sortKey = key;
            _descending = descending;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        if (freeAgents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('No free agents match that filter.')),
          )
        else
          for (var i = 0; i < freeAgents.length; i++) ...[
            _PlayerMarketRow(
              franchise: franchise,
              player: freeAgents[i],
              subtitle: 'Free Agent',
              accentColor: theme.colorScheme.outline,
              jersey: null,
              trailing: hasOpenSpot
                  ? FilledButton(
                      onPressed: _isSigning
                          ? null
                          : () => _sign(freeAgents[i].id),
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
            if (i != freeAgents.length - 1)
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

/// The real Trade Board -- up to [kTradeOfferCount] live AI offers,
/// regenerated deterministically off the current game day every time this
/// tab rebuilds (`generateTradeOffers`). Watches [currentFranchiseProvider]
/// directly (rather than trusting the static [franchise] snapshot every
/// other tab on this screen gets away with) so accepting or declining an
/// offer updates this list in place -- a GM reviewing 5 offers at once
/// needs to act on several without the screen popping out from under them
/// after each one, unlike Free Agents' one-and-done "Sign".
class _TradeBoardTab extends ConsumerStatefulWidget {
  const _TradeBoardTab({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_TradeBoardTab> createState() => _TradeBoardTabState();
}

class _TradeBoardTabState extends ConsumerState<_TradeBoardTab> {
  String? _busyOfferId;

  @override
  Widget build(BuildContext context) {
    final franchise =
        ref.watch(currentFranchiseProvider).value ?? widget.franchise;
    final windowOpen = isTradeWindowOpen(franchise);

    Player? tradeBlockPlayer;
    if (franchise.tradeBlockPlayerId != null) {
      for (final m in franchise.roster) {
        if (m.player.id == franchise.tradeBlockPlayerId) {
          tradeBlockPlayer = m.player;
          break;
        }
      }
    }

    final offers = windowOpen
        ? generateTradeOffers(franchise)
              .where((o) => !franchise.resolvedTradeOfferIds.contains(o.id))
              .toList()
        : const <TradeOffer>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _PreviewBanner(
          text: windowOpen
              ? 'Real offers from around the league -- accept or decline, '
                    'no negotiating. Every offer is already legal for that '
                    'team\'s own coaching staff, so what you see is what '
                    'you\'d get. The trade deadline is the end of Week '
                    '$kTradeDeadlineWeek.'
              : 'The trade deadline has passed -- it closed at the end of '
                    'Week $kTradeDeadlineWeek. Check back next season.',
        ),
        _TradeBlockCard(
          franchise: franchise,
          tradeBlockPlayer: tradeBlockPlayer,
          enabled: windowOpen,
        ),
        if (windowOpen) ...[
          const SizedBox(height: AppSpacing.md),
          if (offers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'No live offers on the board right now -- check back '
                  'after your next game.',
                ),
              ),
            )
          else
            for (var i = 0; i < offers.length; i++) ...[
              _TradeOfferCard(
                franchise: franchise,
                offer: offers[i],
                busy: _busyOfferId == offers[i].id,
                onAccept: () => _accept(offers[i]),
                onDecline: () => _decline(offers[i]),
              ),
              if (i != offers.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ],
    );
  }

  Future<void> _accept(TradeOffer offer) async {
    setState(() => _busyOfferId = offer.id);
    await ref.read(currentFranchiseProvider.notifier).acceptTradeOffer(offer);
    if (mounted) setState(() => _busyOfferId = null);
  }

  Future<void> _decline(TradeOffer offer) async {
    setState(() => _busyOfferId = offer.id);
    await ref
        .read(currentFranchiseProvider.notifier)
        .declineTradeOffer(offer.id);
    if (mounted) setState(() => _busyOfferId = null);
  }
}

/// The GM's own trade-block flag -- "put a player on the trade block
/// (only one allowed), and the trade board should TRY to have 3 (out of
/// the 5) involve that player" (direct GM ask, see
/// `trading-and-hidden-gems-notes.md`). Set/clear via a bottom sheet, the
/// same pattern `team_roster_screen.dart`'s empty-slot "Assign" already
/// uses for picking one player out of a list.
class _TradeBlockCard extends StatelessWidget {
  const _TradeBlockCard({
    required this.franchise,
    required this.tradeBlockPlayer,
    required this.enabled,
  });

  final Franchise franchise;
  final Player? tradeBlockPlayer;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_offer_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trade Block', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  tradeBlockPlayer == null
                      ? 'No player flagged -- other teams have no reason '
                            'to specifically target anyone on your roster.'
                      : '${tradeBlockPlayer!.name} is flagged. The board '
                            'tries to build offers around her.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (enabled) ...[
            const SizedBox(width: AppSpacing.sm),
            if (tradeBlockPlayer != null)
              Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => ref
                      .read(currentFranchiseProvider.notifier)
                      .setTradeBlockPlayer(null),
                  child: const Text('Clear'),
                ),
              ),
            OutlinedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _TradeBlockPickerSheet(franchise: franchise),
              ),
              child: Text(tradeBlockPlayer == null ? 'Set' : 'Change'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every active-roster player, tap to flag her as the trade block --
/// mirrors `team_roster_screen.dart`'s `_AssignPlayerSheet` shape (a
/// title, a scrollable candidate list, tap-to-act-and-pop) without
/// reusing that class directly since it's private to its own file.
class _TradeBlockPickerSheet extends ConsumerWidget {
  const _TradeBlockPickerSheet({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final candidates =
        franchise.roster.where((m) => m.status == RosterStatus.active).toList()
          ..sort(
            (a, b) =>
                b.player.ratings.overall.compareTo(a.player.ratings.overall),
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Put a player on the Trade Block',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final membership in candidates)
                    ListTile(
                      leading: CircleAvatar(
                        child: Text('${membership.player.ratings.overall}'),
                      ),
                      title: Text(membership.player.name),
                      subtitle: Text(
                        '${membership.player.primaryPosition.abbreviation} '
                        '· Age ${membership.player.age}',
                      ),
                      trailing:
                          membership.player.id == franchise.tradeBlockPlayerId
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () async {
                        await ref
                            .read(currentFranchiseProvider.notifier)
                            .setTradeBlockPlayer(membership.player.id);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One live [TradeOffer] -- the offering team, a character tag, both
/// sides' assets, and Accept/Decline. [busy] disables both buttons while
/// this specific offer's action is in flight, so a fast double-tap can't
/// fire it twice.
class _TradeOfferCard extends StatelessWidget {
  const _TradeOfferCard({
    required this.franchise,
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Franchise franchise;
  final TradeOffer offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiTeam = franchise.league.aiTeams.firstWhere(
      (t) => t.team.abbreviation == offer.offeringTeamAbbreviation,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(aiTeam.team.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  aiTeam.team.name,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              _CharacterChip(character: offer.character),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _TradeAssetColumn(
            label: 'You Get',
            assets: offer.offeredToYou,
            currentSeason: franchise.season,
          ),
          const SizedBox(height: AppSpacing.sm),
          _TradeAssetColumn(
            label: 'You Give',
            assets: offer.askedFromYou,
            currentSeason: franchise.season,
          ),
          const SizedBox(height: AppSpacing.sm),
          // A direct GM ask (2026-08-20): "each trade needs a details
          // screen, where all the players involved are there, I can see
          // every detail about each player." Reuses `PlayerDetailScreen`
          // per-player (full ratings/traits/season stats/awards) rather
          // than re-building any of that here.
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TradeOfferDetailScreen(
                    franchise: franchise,
                    offer: offer,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('View Full Details'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single [offer]'s full detail -- every player involved shown with
/// their real identity block (photo, OVR, star tier, POT, OFF/DEF/PHY),
/// each tappable through to `PlayerDetailScreen`'s full profile (ratings,
/// traits, this season's stats, awards) -- a direct GM ask (2026-08-20):
/// "each trade needs a details screen, where all the players involved
/// are there, I can see every detail about each player." Accept/Decline
/// live here too, so a GM who came here to actually look closely doesn't
/// need to back out to the board just to commit.
class TradeOfferDetailScreen extends ConsumerStatefulWidget {
  const TradeOfferDetailScreen({
    required this.franchise,
    required this.offer,
    super.key,
  });

  final Franchise franchise;
  final TradeOffer offer;

  @override
  ConsumerState<TradeOfferDetailScreen> createState() =>
      _TradeOfferDetailScreenState();
}

class _TradeOfferDetailScreenState
    extends ConsumerState<TradeOfferDetailScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final franchise =
        ref.watch(currentFranchiseProvider).value ?? widget.franchise;
    final offer = widget.offer;
    final alreadyResolved = franchise.resolvedTradeOfferIds.contains(offer.id);
    final aiTeam = franchise.league.aiTeams.firstWhere(
      (t) => t.team.abbreviation == offer.offeringTeamAbbreviation,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trade Offer')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Row(
                children: [
                  Text(aiTeam.team.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      aiTeam.team.name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  _CharacterChip(character: offer.character),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('You Get', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final asset in offer.offeredToYou) ...[
              _TradeDetailAssetTile(
                franchise: franchise,
                asset: asset,
                accentColor: aiTeam.team.colors.primary,
                jersey: parseHexColor(aiTeam.team.colors.primaryHex),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text('You Give', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final asset in offer.askedFromYou) ...[
              _TradeDetailAssetTile(
                franchise: franchise,
                asset: asset,
                accentColor: franchise.team.colors.primary,
                jersey: parseHexColor(franchise.team.colors.primaryHex),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            if (alreadyResolved)
              const Text(
                'This offer has already been resolved.',
                textAlign: TextAlign.center,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _accept,
                      child: _busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    await ref
        .read(currentFranchiseProvider.notifier)
        .acceptTradeOffer(widget.offer);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    await ref
        .read(currentFranchiseProvider.notifier)
        .declineTradeOffer(widget.offer.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// One [TradeAsset] row for [TradeOfferDetailScreen] -- a full identity
/// block for a player (unlike the Trade Board list's compact
/// `_TradeAssetTile`), tappable through to `PlayerDetailScreen`'s full
/// profile. [PickTradeAsset] gets the same plain icon-and-label treatment
/// `_TradeAssetTile` already uses -- there's still no player underneath a
/// pick to show a profile for.
class _TradeDetailAssetTile extends StatelessWidget {
  const _TradeDetailAssetTile({
    required this.franchise,
    required this.asset,
    required this.accentColor,
    required this.jersey,
  });

  final Franchise franchise;
  final TradeAsset asset;
  final Color accentColor;
  final RgbColor? jersey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (asset) {
      PlayerTradeAsset(:final player) => AppCard(
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(
                  franchise: franchise,
                  playerId: player.id,
                ),
              ),
            );
          },
          child: Row(
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
                      '${player.primaryPosition.abbreviation} ${player.name}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Age ${player.age} · ${experienceLabel(player)}',
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
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
      PickTradeAsset(:final draftSeason) => AppCard(
        child: Row(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${asset.label} '
                '(${pickHorizonLabel(draftSeason, franchise.season)})',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    };
  }
}

/// "You Get"/"You Give", each a short label over one row per asset.
class _TradeAssetColumn extends StatelessWidget {
  const _TradeAssetColumn({
    required this.label,
    required this.assets,
    required this.currentSeason,
  });

  final String label;
  final List<TradeAsset> assets;

  /// [Franchise.season] right now -- what [_TradeAssetTile] compares a
  /// [PickTradeAsset.draftSeason] against to phrase "next draft" vs "the
  /// draft after" (`pick_ownership.dart`'s `pickHorizonLabel`).
  final int currentSeason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final asset in assets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _TradeAssetTile(asset: asset, currentSeason: currentSeason),
          ),
      ],
    );
  }
}

/// One [TradeAsset] row -- an OVR badge and identity line for a player,
/// or a plain icon-and-label for a pick (there's no player underneath a
/// pick to show a badge for). A pick's row also names which of the
/// [kTradeablePickHorizonSeasons] upcoming drafts it's for
/// (`pick_ownership.dart`'s `pickHorizonLabel`, compared against
/// [currentSeason]) -- "next draft" reads very differently from "the
/// draft after" to a GM deciding whether to take one.
class _TradeAssetTile extends StatelessWidget {
  const _TradeAssetTile({required this.asset, required this.currentSeason});

  final TradeAsset asset;
  final int currentSeason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (asset) {
      PlayerTradeAsset(:final player) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${player.ratings.overall}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${player.primaryPosition.abbreviation} ${player.name} · '
              'Age ${player.age}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // A direct GM ask (2026-08-20): "on the trade board screen, we
          // need to add potential somewhere" -- same purple "POT" tone
          // the Market screen's own player rows already use
          // (`StatChipRow`'s `extra` POT chip), so it reads as the same
          // concept here.
          StatChip(
            label: 'POT',
            value: player.ratings.potential,
            color: statChipTone(context, Colors.purple),
          ),
        ],
      ),
      PickTradeAsset(:final draftSeason) => Row(
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${asset.label} (${pickHorizonLabel(draftSeason, currentSeason)})',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    };
  }
}

/// [TradeOfferCharacter] as a small colored pill -- same visual language
/// as `StatChip`, but for a fixed short label rather than a number.
class _CharacterChip extends StatelessWidget {
  const _CharacterChip({required this.character});

  final TradeOfferCharacter character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, swatch) = switch (character) {
      TradeOfferCharacter.value => ('Value', Colors.blueGrey),
      TradeOfferCharacter.winNow => ('Win-Now', Colors.orange),
      TradeOfferCharacter.rebuilding => ('Rebuilding', Colors.teal),
      TradeOfferCharacter.aggressive => ('Aggressive', Colors.red),
    };
    final color = statChipTone(context, swatch);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
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
