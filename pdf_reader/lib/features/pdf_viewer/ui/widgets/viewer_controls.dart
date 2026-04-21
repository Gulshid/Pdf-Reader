// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ViewerControls extends StatelessWidget {
  const ViewerControls({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.totalPages,
  });

  final PdfViewerController controller;
  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Listener(
        onPointerDown: (_) {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 15.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: cs.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ControlButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onTap: () => controller.zoomLevel =
                      (controller.zoomLevel - 0.25).clamp(0.5, 5.0),
                ),
                _Divider(),
                _ControlButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous page',
                  onTap:
                      currentPage > 0 ? () => controller.previousPage() : null,
                ),
                _PageIndicator(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onTap: () => _showJumpDialog(context),
                  onLongPress: () {
                    // Long-press resets zoom
                    HapticFeedback.mediumImpact();
                    controller.zoomLevel = 1.0;
                  },
                ),
                _ControlButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next page',
                  onTap: currentPage < totalPages - 1
                      ? () => controller.nextPage()
                      : null,
                ),
                _Divider(),
                _ControlButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  onTap: () => controller.zoomLevel =
                      (controller.zoomLevel + 0.25).clamp(0.5, 5.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showJumpDialog(BuildContext context) async {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);
    final controller = TextEditingController();

    final result = await showDialog<int>(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => _JumpToPageDialog(
        controller: controller,
        currentPage: currentPage,
        totalPages: totalPages,
      ),
    );

    if (result != null && result >= 1 && result <= totalPages) {
      this.controller.jumpToPage(result);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page indicator pill — tap to jump, long-press to reset zoom
// ─────────────────────────────────────────────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.currentPage,
    required this.totalPages,
    required this.onTap,
    required this.onLongPress,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${currentPage + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  height: 1.1,
                ),
              ),
              Container(
                width: 16.w,
                height: 1,
                color: cs.outlineVariant,
                margin: EdgeInsets.symmetric(vertical: 1.h),
              ),
              Text(
                '$totalPages',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Control button — no GestureDetector, uses InkWell inside Material
// ─────────────────────────────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(24.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            child: AnimatedOpacity(
              opacity: enabled ? 1.0 : 0.28,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                icon,
                size: 20.sp,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin vertical divider between button groups
// ─────────────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20.h,
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Jump-to-page dialog
// ─────────────────────────────────────────────────────────────────────────────
class _JumpToPageDialog extends StatefulWidget {
  const _JumpToPageDialog({
    required this.controller,
    required this.currentPage,
    required this.totalPages,
  });

  final TextEditingController controller;
  final int currentPage;
  final int totalPages;

  @override
  State<_JumpToPageDialog> createState() => _JumpToPageDialogState();
}

class _JumpToPageDialogState extends State<_JumpToPageDialog> {
  String? _error;

  void _submit() {
    final value = int.tryParse(widget.controller.text.trim());
    if (value == null || value < 1 || value > widget.totalPages) {
      setState(() => _error = 'Enter a page between 1 and ${widget.totalPages}');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      title: Text(
        'Jump to page',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Current: ${widget.currentPage + 1} of ${widget.totalPages}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: widget.controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
            decoration: InputDecoration(
              hintText: '${widget.currentPage + 1}',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 12.h,
                horizontal: 16.w,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Go'),
        ),
      ],
    );
  }
}