import 'package:flutter/material.dart';

/// Reserves layout space for a future AdMob banner without integrating the
/// SDK. Shared across every screen that will eventually carry an ad
/// (dashboard now, gameplay later) so they reserve space consistently.
class AdPlacementPlaceholder extends StatelessWidget {
  const AdPlacementPlaceholder({required this.placement, super.key});

  final String placement;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$placement reserved for an advertisement',
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$placement — reserved'),
      ),
    );
  }
}
