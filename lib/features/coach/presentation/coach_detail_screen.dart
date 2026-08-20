import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/presentation/player_card_widgets.dart' show StatChip, statChipTone;
import '../../portrait/presentation/portrait_editor_screen.dart';
import '../../portrait/presentation/portrait_image.dart';
import '../domain/coach.dart';
import '../domain/coach_archetype.dart';

/// The GM's own head coach's full profile -- a direct GM ask
/// (2026-08-19): "Head coach needs a detail screen. Stats, career
/// wins/losses, any trophies, how long they've been a head coach, etc."
/// Reachable from `team_roster_screen.dart`'s `_CoachRow`, same "row
/// leads to a full detail screen" pattern `PlayerDetailScreen` already
/// established -- portrait editing, this screen's old entry point, moves
/// to a tap on the portrait itself here, mirroring
/// `PlayerDetailScreen`'s own header exactly.
///
/// Deliberately GM-own-coach-only -- no AI team's coach has a row that
/// leads here, and [Coach.seasonsAsHeadCoach]/[Coach.careerWins]/
/// [Coach.careerLosses]/[Coach.championshipsWon] are only ever tracked
/// for the GM's own hire in the first place (`Coach.copyWithSeasonRecord`'s
/// own doc comment).
const _kHeroPortraitSize = 128.0;

class CoachDetailScreen extends StatelessWidget {
  const CoachDetailScreen({required this.franchise, super.key});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coach = franchise.coach;
    final winPct = coach.careerWins + coach.careerLosses == 0
        ? null
        : coach.careerWins / (coach.careerWins + coach.careerLosses);

    return Scaffold(
      appBar: AppBar(title: Text(coach.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PortraitEditorScreen(franchise: franchise),
                            ),
                          );
                        },
                        child: PortraitImage(
                          saveId: franchise.id,
                          ownerId: 'coach',
                          appearance: coach.appearance,
                          size: _kHeroPortraitSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(coach.name, style: theme.textTheme.headlineSmall),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      '${coach.archetype.label} · Age ${coach.age}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      coach.seasonsAsHeadCoach == 0
                          ? 'First season as head coach'
                          : coach.seasonsAsHeadCoach == 1
                          ? '1 season as head coach'
                          : '${coach.seasonsAsHeadCoach} seasons as head '
                                'coach',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Career Record', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      label: 'Record',
                      value: '${coach.careerWins}-${coach.careerLosses}',
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      label: 'Win %',
                      value: winPct == null
                          ? '--'
                          : '${(winPct * 100).round()}%',
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      label: coach.championshipsWon == 1
                          ? 'Championship'
                          : 'Championships',
                      value: '${coach.championshipsWon}',
                      icon: coach.championshipsWon > 0
                          ? Icons.emoji_events
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Coaching Stats', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatChip(
                    label: 'OFF',
                    value: coach.stats.offense,
                    color: statChipTone(context, Colors.orange),
                  ),
                  StatChip(
                    label: 'DEF',
                    value: coach.stats.defense,
                    color: statChipTone(context, Colors.blue),
                  ),
                  StatChip(
                    label: 'DEV',
                    value: coach.stats.development,
                    color: statChipTone(context, Colors.green),
                  ),
                  StatChip(
                    label: 'MOT',
                    value: coach.stats.motivation,
                    color: statChipTone(context, Colors.pink),
                  ),
                  StatChip(
                    label: 'MGT',
                    value: coach.stats.management,
                    color: statChipTone(context, Colors.teal),
                  ),
                  StatChip(
                    label: 'OVR',
                    value: coach.stats.overall,
                    color: statChipTone(context, Colors.blueGrey),
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

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.amber.shade700),
          const SizedBox(height: 2),
        ],
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
