import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';

/// Centered loading indicator for a screen or section that's loading data.
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BouncingBasketball(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A bouncing basketball emoji standing in for a spinner. Drives itself with
/// `Curves.bounceOut` so it drops and settles with a couple of real bounces
/// rather than just easing to a stop, then repeats.
class _BouncingBasketball extends StatefulWidget {
  const _BouncingBasketball();

  @override
  State<_BouncingBasketball> createState() => _BouncingBasketballState();
}

class _BouncingBasketballState extends State<_BouncingBasketball>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  static const _dropHeight = 32.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drop = CurvedAnimation(parent: _controller, curve: Curves.bounceOut);

    return Semantics(
      label: 'Loading',
      child: SizedBox(
        height: _dropHeight + 24,
        width: 40,
        child: AnimatedBuilder(
          animation: drop,
          builder: (context, child) {
            final settled = drop.value.clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.15 + (0.25 * settled),
                    child: Transform.scale(
                      scaleX: 0.7 + (0.3 * settled),
                      child: Container(
                        width: 22,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -_dropHeight * (1 - drop.value)),
                  child: const ExcludeSemantics(
                    child: Text('🏀', style: TextStyle(fontSize: 28)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Centered "nothing here yet" state, with an optional action (e.g. "Create
/// a franchise").
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        // Announces the empty state to screen readers as soon as it appears,
        // since nothing else on an empty screen would otherwise draw focus.
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered error state with an optional retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
