import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/models/conversion_task_model.dart';

/// A self-contained widget that visualises the state of a running conversion.
///
/// Shows:
///  • An animated indeterminate bar while the status is [ConversionStatus.running]
///    and [progress] is still 0.
///  • A determinate bar + percentage label once progress > 0.
///  • A success indicator when [ConversionStatus.done].
///  • An error message when [ConversionStatus.failed].
class ConversionProgress extends StatelessWidget {
  const ConversionProgress({
    super.key,
    required this.status,
    required this.progress,
    this.outputPath,
    this.error,
    this.sourceLabel,
    this.targetLabel,
  });

  final ConversionStatus status;

  /// 0.0 → 1.0
  final double progress;

  /// Populated once [status] is [ConversionStatus.done].
  final String? outputPath;

  /// Populated when [status] is [ConversionStatus.failed].
  final String? error;

  /// e.g. "PDF"
  final String? sourceLabel;

  /// e.g. "TXT"
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ConversionStatus.running => _RunningView(
          progress: progress,
          sourceLabel: sourceLabel,
          targetLabel: targetLabel,
        ),
      ConversionStatus.done => _DoneView(outputPath: outputPath),
      ConversionStatus.failed => _ErrorView(error: error),
      ConversionStatus.idle => const SizedBox.shrink(),
    };
  }
}

// ── Running ──────────────────────────────────────────────────────────────────

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.progress,
    this.sourceLabel,
    this.targetLabel,
  });

  final double progress;
  final String? sourceLabel;
  final String? targetLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final indeterminate = progress <= 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (sourceLabel != null && targetLabel != null)
              Text(
                '$sourceLabel → $targetLabel',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                  letterSpacing: 0.4,
                ),
              )
            else
              Text(
                'Converting…',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
            if (!indeterminate)
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: indeterminate
              ? LinearProgressIndicator(
                  minHeight: 6.h,
                  backgroundColor: cs.primary.withOpacity(0.15),
                )
              : LinearProgressIndicator(
                  value: progress,
                  minHeight: 6.h,
                  backgroundColor: cs.primary.withOpacity(0.15),
                ),
        ),

        SizedBox(height: 12.h),

        // Animated dots hint
        Center(
          child: Text(
            'Please wait, do not close the app',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withOpacity(0.45),
              fontSize: 11.sp,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Done ─────────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({this.outputPath});
  final String? outputPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const successGreen = Color(0xFF2E7D32);

    return Column(
      children: [
        Icon(Icons.check_circle_rounded, color: successGreen, size: 48.sp),
        SizedBox(height: 8.h),
        Text(
          'Conversion complete!',
          style: theme.textTheme.titleLarge?.copyWith(color: successGreen),
          textAlign: TextAlign.center,
        ),
        if (outputPath != null) ...[
          SizedBox(height: 6.h),
          Text(
            outputPath!,
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: cs.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversion failed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (error != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    error!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}