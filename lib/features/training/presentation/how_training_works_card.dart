import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';

/// A brief, plain-language summary of how weekly training actually
/// works -- direct GM quote: "I am writing the program, and even I
/// don't know how it works" (2026-08-10, TODO.md item 6). This is
/// deliberately short (a handful of sentences, no numbers); the full
/// breakdown with 3 worked examples lives in a separate detailed
/// reference doc, matching this project's established HTML-artifact
/// convention for design/reference docs -- this card just gets the GM
/// oriented without leaving the screen.
///
/// Public (2026-08-19, promoted out of `training_screen.dart` where it
/// used to live private and screen-local) so `GuideScreen`'s Training
/// section can show the exact same copy rather than a second, driftable
/// copy of it -- a direct GM ask for the Guide's Training section to be
/// "just a copy-over of the 'How Training Works' section from the
/// training page."
class HowTrainingWorksCard extends StatelessWidget {
  const HowTrainingWorksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How Training Works', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Every week, active and developmental players inch toward '
            'their potential -- the bigger the gap between where they '
            'are now and their ceiling, the faster they grow, especially '
            'with real minutes on the floor. A bench player who barely '
            'plays barely develops, no matter how high their potential '
            'is.\n\n'
            'Past their prime (around 30 and up), players decline a '
            'little each week too, with the rest of a veteran\'s yearly '
            'decline landing in one lump at the end of the season.\n\n'
            'Team Focus decides which ratings move for everyone by '
            'default. Give a player to one of your 3 individual coaches '
            'to override that just for them -- a broad direction, or one '
            'specific rating to really hyper-focus.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
