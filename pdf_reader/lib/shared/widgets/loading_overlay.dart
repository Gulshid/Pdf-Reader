import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A full-screen modal overlay that blocks user interaction while a background
/// operation is in progress.
///
/// Wrap your screen body with [LoadingOverlay] and toggle [isLoading]:
///
/// ```dart
/// LoadingOverlay(
///   isLoading: _isSaving,
///   message: 'Saving file…',
///   child: YourScreenBody(),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.opacity = 0.55,
  });

  /// Whether the overlay is visible and input is blocked.
  final bool isLoading;

  /// The widget shown underneath the overlay.
  final Widget child;

  /// Optional label shown below the spinner.
  final String? message;

  /// Opacity of the dark scrim (0.0 – 1.0). Defaults to 0.55.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          // Scrim
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false, // intentionally blocks taps
              child: ColoredBox(
                color: Colors.black.withOpacity(opacity),
              ),
            ),
          ),
          // Spinner card
          Center(
            child: _SpinnerCard(message: message),
          ),
        ],
      ],
    );
  }
}

class _SpinnerCard extends StatelessWidget {
  const _SpinnerCard({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 20.h),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}