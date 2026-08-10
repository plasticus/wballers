import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../coach/domain/coach.dart';
import '../../coach/domain/coach_archetype.dart';
import '../../coach/generation/coach_generator.dart';
import '../../league/domain/team.dart';
import '../../portrait/domain/portrait_manifest.dart';
import '../../portrait/domain/portrait_weights.dart';
import '../../portrait/persistence/portrait_catalog_loader.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../application/current_franchise_provider.dart';
import 'expansion_franchise_factory.dart';

/// Step 2 of onboarding: a real staffing decision, not an auto-assigned
/// coach. Shows 3 head-coach candidates -- distinct archetypes, "super
/// comparable, just different goals in mind" per the GM's own framing --
/// generated deterministically from the identity step's `simulationSeed`
/// (`generateCoachCandidates`). The GM's pick becomes the franchise's
/// actual head coach; only then does the franchise actually get created.
/// Re-hiring a different coach later is explicitly future (off-season)
/// work, not built here.
class CoachSelectionScreen extends ConsumerStatefulWidget {
  const CoachSelectionScreen({
    required this.gmName,
    required this.clubName,
    required this.homeCity,
    required this.homeState,
    required this.abbreviation,
    required this.conference,
    required this.simulationSeed,
    required this.replacedTeamAbbreviation,
    required this.colors,
    required this.emoji,
    super.key,
  });

  final String gmName;
  final String clubName;
  final String homeCity;
  final String homeState;
  final String abbreviation;
  final Conference conference;
  final int simulationSeed;
  final String replacedTeamAbbreviation;
  final TeamColors colors;
  final String emoji;

  @override
  ConsumerState<CoachSelectionScreen> createState() =>
      _CoachSelectionScreenState();
}

class _CoachSelectionScreenState extends ConsumerState<CoachSelectionScreen> {
  // Memoized the first time portrait data is ready, not regenerated on
  // every rebuild (e.g. every time the GM taps a different candidate) --
  // still fully deterministic for the seed either way, just avoids
  // redoing 3 portrait generations on every selection tap.
  List<Coach>? _candidates;
  Coach? _selected;
  var _isSubmitting = false;

  List<Coach> _candidatesFor(
    PortraitWeights weights,
    PortraitManifest manifest,
  ) {
    return _candidates ??= generateCoachCandidates(
      Random(widget.simulationSeed),
      portraitWeights: weights,
      portraitManifest: manifest,
    );
  }

  Future<void> _createFranchise(
    Coach coach,
    PortraitWeights weights,
    PortraitManifest manifest,
  ) async {
    setState(() => _isSubmitting = true);
    final franchise = createExpansionFranchise(
      gmName: widget.gmName,
      clubName: widget.clubName,
      homeCity: widget.homeCity,
      homeState: widget.homeState,
      abbreviation: widget.abbreviation,
      conference: widget.conference,
      simulationSeed: widget.simulationSeed,
      replacedTeamAbbreviation: widget.replacedTeamAbbreviation,
      colors: widget.colors,
      emoji: widget.emoji,
      coach: coach,
      portraitWeights: weights,
      portraitManifest: manifest,
    );

    await ref
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    if (!mounted) return;
    // Two onboarding screens are on the stack (identity, then this one)
    // above the Dashboard -- pop both in one go rather than popping twice.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final weightsAsync = ref.watch(portraitWeightsProvider);
    final manifestAsync = ref.watch(portraitManifestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hire Your Head Coach')),
      body: SafeArea(
        child: switch ((weightsAsync, manifestAsync)) {
          (AsyncData(value: final weights), AsyncData(value: final manifest)) =>
            _buildBody(context, weights, manifest),
          (AsyncError(), _) || (_, AsyncError()) => const ErrorStateView(
            message: 'Could not load coach candidates.',
          ),
          _ => const LoadingView(message: 'Loading coach candidates…'),
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
    final candidates = _candidatesFor(weights, manifest);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'As the new GM of ${widget.clubName} ${widget.emoji}, your '
            'first task is to select a Head Coach. These are the three '
            'leading candidates:',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final candidate in candidates) ...[
            _CoachCandidateCard(
              coach: candidate,
              isSelected: identical(_selected, candidate),
              onTap: () => setState(() => _selected = candidate),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            onPressed: _selected == null || _isSubmitting
                ? null
                : () => _createFranchise(_selected!, weights, manifest),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm & Create Franchise'),
          ),
        ],
      ),
    );
  }
}

class _CoachCandidateCard extends StatelessWidget {
  const _CoachCandidateCard({
    required this.coach,
    required this.isSelected,
    required this.onTap,
  });

  final Coach coach;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PortraitImage(
                  saveId: 'onboarding-preview',
                  ownerId: 'candidate-${coach.name}',
                  appearance: coach.appearance,
                  size: 56,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              coach.name,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                      Text(
                        coach.archetype.label,
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
          ),
        ),
      ),
    );
  }
}
