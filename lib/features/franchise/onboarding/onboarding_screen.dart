import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../league/domain/team.dart';
import '../application/current_franchise_provider.dart';
import 'expansion_franchise_factory.dart';

/// Name yourself (the GM) and the club, choose a conference, and generate
/// a weak starting roster with a hired coach. Phase 1's expansion
/// onboarding flow.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _gmNameController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _homeCityController = TextEditingController();
  var _conference = Conference.atlantic;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _gmNameController,
      _clubNameController,
      _homeCityController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _gmNameController.dispose();
    _clubNameController.dispose();
    _homeCityController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _gmNameController.text.trim().isNotEmpty &&
      _clubNameController.text.trim().isNotEmpty &&
      _homeCityController.text.trim().isNotEmpty;

  Future<void> _createFranchise() async {
    setState(() => _isSubmitting = true);

    // The one place real (non-seeded) randomness enters the system --
    // everything the seed drives from here on is deterministic.
    final simulationSeed = Random().nextInt(1 << 31);
    final franchise = createExpansionFranchise(
      gmName: _gmNameController.text.trim(),
      clubName: _clubNameController.text.trim(),
      homeCity: _homeCityController.text.trim(),
      conference: _conference,
      simulationSeed: simulationSeed,
    );

    await ref
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Expansion Franchise')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Every legend starts with an expansion team.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "You're the General Manager: build the roster and set the "
                'direction. Your coach handles in-game decisions.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _gmNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name (General Manager)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _clubNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Club name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _homeCityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Home city',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Conference', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<Conference>(
                segments: const [
                  ButtonSegment(
                    value: Conference.atlantic,
                    label: Text('Atlantic'),
                  ),
                  ButtonSegment(
                    value: Conference.pacific,
                    label: Text('Pacific'),
                  ),
                ],
                selected: {_conference},
                onSelectionChanged: (selection) =>
                    setState(() => _conference = selection.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _isValid && !_isSubmitting ? _createFranchise : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Franchise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
