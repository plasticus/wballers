import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/position.dart';
import '../../player/presentation/player_card_widgets.dart';
import '../../player/presentation/trait_chip.dart';
import '../domain/draft_in_progress.dart';
import '../domain/draft_pick.dart';
import '../domain/draft_prospect.dart';
import '../generation/draft_generator.dart'
    show draftProspectValue, kDraftRounds;

/// Draft Day: the GM's real, interactive draft
/// (`0D_Season_2_Roadmap.md`'s "The draft, for real" stage, 2026-08-11).
/// Reached from `SeasonRecapScreen`'s "Begin Next Season" button, which
/// calls `beginNextSeasonAndPersist` first -- by the time this screen is
/// on-screen, [Franchise.draftInProgress] already exists and every AI
/// pick before the GM's own first turn has already resolved
/// (`current_franchise_provider.dart`'s own doc comments explain why).
///
/// Watches [currentFranchiseProvider] directly rather than taking a
/// static `franchise` constructor param -- every other screen with a
/// write action that changes what's on-screen (`TeamRosterScreen`,
/// `_FreeAgentsTab`) does the same, since a pick genuinely changes what
/// this screen needs to show next (the *next* pick's prospect list),
/// not just some other screen the GM will see after navigating back.
class DraftDayScreen extends ConsumerWidget {
  const DraftDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchiseState = ref.watch(currentFranchiseProvider);

    return switch (franchiseState) {
      AsyncData(:final value?) => _DraftDayView(franchise: value),
      AsyncData() => const _NoDraftView(),
      AsyncError() => const ErrorStateView(
        message: 'Could not load your franchise save.',
      ),
      _ => const LoadingView(message: 'Loading the draft…'),
    };
  }
}

class _NoDraftView extends StatelessWidget {
  const _NoDraftView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Draft Day')),
      body: const EmptyStateView(
        icon: Icons.groups_outlined,
        message: 'There\'s no franchise to draft for.',
      ),
    );
  }
}

class _DraftDayView extends ConsumerStatefulWidget {
  const _DraftDayView({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_DraftDayView> createState() => _DraftDayViewState();
}

class _DraftDayViewState extends ConsumerState<_DraftDayView> {
  var _isPicking = false;

  /// The GM's own picks made from *this* screen, in the order made --
  /// purely local/display state. Not derived from [Franchise] at all: by
  /// the time a draft finishes, `makeDraftPick` has already cleared
  /// [Franchise.draftInProgress] and [Franchise.draftClass] (see
  /// `draft_advancer.dart`'s `finalizeDraft`), so there'd be nothing left
  /// to derive a "what did I just draft" summary from otherwise.
  final _ownPicksThisDraft = <DraftPick>[];

  Future<void> _draft(
    DraftProspect prospect, {
    required int round,
    required int pickNumber,
  }) async {
    setState(() => _isPicking = true);
    _ownPicksThisDraft.add(
      DraftPick(
        round: round,
        pickNumber: pickNumber,
        teamAbbreviation: widget.franchise.team.abbreviation,
        prospect: prospect,
      ),
    );
    await ref
        .read(currentFranchiseProvider.notifier)
        .makeDraftPick(prospect.player.id);
    if (!mounted) return;
    setState(() => _isPicking = false);
  }

  @override
  Widget build(BuildContext context) {
    final franchise = widget.franchise;
    final draft = franchise.draftInProgress;

    return Scaffold(
      appBar: AppBar(title: const Text('Draft Day')),
      body: SafeArea(
        child: draft == null
            ? _CompleteBody(ownPicks: _ownPicksThisDraft)
            : _InProgressBody(
                franchise: franchise,
                draft: draft,
                isPicking: _isPicking,
                onDraft: (prospect) => _draft(
                  prospect,
                  round: draft.nextRound,
                  pickNumber: draft.nextOverallPick,
                ),
              ),
      ),
    );
  }
}

class _CompleteBody extends StatelessWidget {
  const _CompleteBody({required this.ownPicks});

  final List<DraftPick> ownPicks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (ownPicks.isEmpty) {
      return const EmptyStateView(
        icon: Icons.event_busy_outlined,
        message: 'There\'s no draft in progress right now.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.celebration_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Draft Complete', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Every pick has landed on a roster -- your new rookies are '
                'already on your active roster.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Your Picks', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < ownPicks.length; i++) ...[
          _PickSummaryRow(pick: ownPicks[i]),
          if (i != ownPicks.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _PickSummaryRow extends StatelessWidget {
  const _PickSummaryRow({required this.pick});

  final DraftPick pick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = pick.prospect.player;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${player.primaryPosition.abbreviation} ${player.name}',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '${pick.prospect.college.name} · Round ${pick.round}, '
                  'Pick ${pick.pickNumber}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${player.ratings.overall} OVR',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _InProgressBody extends StatelessWidget {
  const _InProgressBody({
    required this.franchise,
    required this.draft,
    required this.isPicking,
    required this.onDraft,
  });

  final Franchise franchise;
  final DraftInProgress draft;
  final bool isPicking;
  final void Function(DraftProspect prospect) onDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwnTurn = draft.onTheClock == franchise.team.abbreviation;
    final pickedIds = {for (final pick in draft.picks) pick.prospect.player.id};
    final available =
        franchise.draftClass
            .where((prospect) => !pickedIds.contains(prospect.player.id))
            .toList()
          ..sort(
            (a, b) => draftProspectValue(b).compareTo(draftProspectValue(a)),
          );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Round ${draft.nextRound} of $kDraftRounds',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Pick #${draft.nextOverallPick} overall',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isOwnTurn)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!isOwnTurn)
          const Text('Other teams are picking…')
        else ...[
          Text('On the Clock: You', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < available.length; i++) ...[
            _ProspectRow(
              franchise: franchise,
              prospect: available[i],
              enabled: !isPicking,
              onDraft: () => onDraft(available[i]),
            ),
            if (i != available.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

/// One draftable prospect, in the same left-rail-plus-stat-chips shape
/// `player_market_screen.dart`'s own `_PlayerMarketRow` already
/// established for the (preview-only) Draft tab -- a GM who's browsed
/// that screen should recognize this as the same "player card" language,
/// just with a real "Draft" action this time instead of a disclaimer.
class _ProspectRow extends StatelessWidget {
  const _ProspectRow({
    required this.franchise,
    required this.prospect,
    required this.enabled,
    required this.onDraft,
  });

  final Franchise franchise;
  final DraftProspect prospect;
  final bool enabled;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = prospect.player;
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
                accentColor: theme.colorScheme.primary,
                jersey: null,
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
                      '${prospect.college.name} · Age ${player.age}',
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
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: enabled ? onDraft : null,
            child: const Text('Draft'),
          ),
        ],
      ),
    );
  }
}
