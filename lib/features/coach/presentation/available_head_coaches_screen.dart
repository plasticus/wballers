import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/persistence/portrait_catalog_loader.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../domain/coach.dart';
import '../domain/coach_archetype.dart';
import '../domain/coach_lifecycle.dart';
import '../generation/coach_generator.dart';

/// Seed offset for this screen's own candidate pool -- next free number
/// after `coach_aging_advancer.dart`'s `kCoachAgingSeedOffset` (24).
/// Stable for as long as the season doesn't change (`franchise.seasonSeed`),
/// so reopening this screen mid-off-season shows the same 10 candidates
/// rather than a fresh roll every visit -- same "recompute, don't
/// persist" posture the Player Market preview tabs already use, just
/// without a reroll button (unlike onboarding's, `coach_selection_screen.dart`
/// -- 10 real candidates already gives plenty to choose from).
const kAvailableHeadCoachesSeedOffset = 25;

/// How many candidates this screen shows -- "you can see 10 or so
/// coaches that are available," a direct GM ask (2026-08-19).
const kAvailableHeadCoachesCount = 10;

/// What [AvailableHeadCoachesScreen] can sort its candidate list by --
/// "sort them by whatever stats -- OVR, or each individual stat," a
/// direct GM ask.
enum CoachSortKey {
  overall,
  offense,
  defense,
  development,
  motivation,
  management,
  age,
}

extension CoachSortKeyLabel on CoachSortKey {
  String get label => switch (this) {
    CoachSortKey.overall => 'Overall',
    CoachSortKey.offense => 'Offense',
    CoachSortKey.defense => 'Defense',
    CoachSortKey.development => 'Development',
    CoachSortKey.motivation => 'Motivation',
    CoachSortKey.management => 'Management',
    CoachSortKey.age => 'Age',
  };

  /// Every stat key reads best-first (a GM scanning by Management wants
  /// the sharpest trader at the top); Age reads youngest-first -- the
  /// more interesting end for a hiring decision, same convention
  /// `PlayerSortKey.age` already uses (more growth seasons ahead).
  bool get _defaultDescending => this != CoachSortKey.age;

  int compare(Coach a, Coach b) {
    final raw = switch (this) {
      CoachSortKey.overall => a.stats.overall.compareTo(b.stats.overall),
      CoachSortKey.offense => a.stats.offense.compareTo(b.stats.offense),
      CoachSortKey.defense => a.stats.defense.compareTo(b.stats.defense),
      CoachSortKey.development => a.stats.development.compareTo(
        b.stats.development,
      ),
      CoachSortKey.motivation => a.stats.motivation.compareTo(
        b.stats.motivation,
      ),
      CoachSortKey.management => a.stats.management.compareTo(
        b.stats.management,
      ),
      CoachSortKey.age => a.age.compareTo(b.age),
    };
    return _defaultDescending ? -raw : raw;
  }
}

/// The GM's own real, off-season head-coach hiring pool -- "the GM can
/// hire a new head coach every off-season, if they want... a new button
/// on the Dashboard... you can see 10 or so coaches that are available,"
/// a direct GM ask (2026-08-19, `coach-lifecycle-notes.md`). Unlike
/// onboarding's `CoachSelectionScreen` (age 49-51, a deliberately
/// stronger one-time starting point), every candidate here is a fresh,
/// just-entering-the-league hire (`kCoachEntryMinAge`-`kCoachEntryMaxAge`)
/// -- the only way to field an *established*, higher-skill coach again is
/// to grow one over time, not to hire one already strong.
///
/// Reachable from the Dashboard's Season card, only while the off-season
/// window is actually open (a champion's been crowned, the next season
/// hasn't started yet) -- gated in the UI, same "gate in the UI, not the
/// provider" shape `isTradeWindowOpen` already established, since nothing
/// else needs `hireHeadCoach` to also re-check it.
class AvailableHeadCoachesScreen extends ConsumerStatefulWidget {
  const AvailableHeadCoachesScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  ConsumerState<AvailableHeadCoachesScreen> createState() =>
      _AvailableHeadCoachesScreenState();
}

class _AvailableHeadCoachesScreenState
    extends ConsumerState<AvailableHeadCoachesScreen> {
  List<Coach>? _candidates;
  var _sortKey = CoachSortKey.overall;
  var _isHiring = false;

  List<Coach> _candidatesFor(
    PortraitWeights weights,
    PortraitManifest manifest,
  ) {
    return _candidates ??= generateCoachCandidates(
      Random(widget.franchise.seasonSeed + kAvailableHeadCoachesSeedOffset),
      count: kAvailableHeadCoachesCount,
      minAge: kCoachEntryMinAge,
      maxAge: kCoachEntryMaxAge,
      portraitWeights: weights,
      portraitManifest: manifest,
    );
  }

  Future<void> _hire(Coach coach) async {
    setState(() => _isHiring = true);
    await ref.read(currentFranchiseProvider.notifier).hireHeadCoach(coach);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final weightsAsync = ref.watch(portraitWeightsProvider);
    final manifestAsync = ref.watch(portraitManifestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Available Head Coaches')),
      body: SafeArea(
        child: switch ((weightsAsync, manifestAsync)) {
          (AsyncData(value: final weights), AsyncData(value: final manifest)) =>
            _buildBody(context, weights, manifest),
          (AsyncError(), _) || (_, AsyncError()) => const ErrorStateView(
            message: 'Could not load available coaches.',
          ),
          _ => const LoadingView(message: 'Loading available coaches…'),
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PortraitWeights weights,
    PortraitManifest manifest,
  ) {
    final theme = Theme.of(context);
    final candidates = [..._candidatesFor(weights, manifest)]
      ..sort(_sortKey.compare);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Text('Sort:', style: theme.textTheme.labelLarge),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<CoachSortKey>(
                value: _sortKey,
                underline: const SizedBox.shrink(),
                items: [
                  for (final key in CoachSortKey.values)
                    DropdownMenuItem(value: key, child: Text(key.label)),
                ],
                onChanged: (key) {
                  if (key != null) setState(() => _sortKey = key);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Hiring replaces your current head coach, effective '
                  'immediately -- there\'s no going back to the old one '
                  'once you do.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (var i = 0; i < candidates.length; i++) ...[
                _AvailableCoachCard(
                  coach: candidates[i],
                  isHiring: _isHiring,
                  onHire: () => _hire(candidates[i]),
                ),
                if (i != candidates.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailableCoachCard extends StatelessWidget {
  const _AvailableCoachCard({
    required this.coach,
    required this.isHiring,
    required this.onHire,
  });

  final Coach coach;
  final bool isHiring;
  final VoidCallback onHire;

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
              PortraitImage(
                saveId: 'available-head-coaches',
                ownerId: 'candidate-${coach.name}',
                appearance: coach.appearance,
                size: 56,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coach.name, style: theme.textTheme.titleMedium),
                    Text(
                      '${coach.archetype.label} · Age ${coach.age} · '
                      'OVR ${coach.stats.overall}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Offense ${coach.stats.offense} · '
                      'Defense ${coach.stats.defense} · '
                      'Development ${coach.stats.development}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Motivation ${coach.stats.motivation} · '
                      'Management ${coach.stats.management}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: isHiring ? null : onHire,
            child: const Text('Hire'),
          ),
        ],
      ),
    );
  }
}
