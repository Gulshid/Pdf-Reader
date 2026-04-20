import 'package:flutter/material.dart';
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
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: () => controller.zoomLevel =
                  (controller.zoomLevel - 0.25).clamp(0.5, 5.0),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_before_rounded),
              onPressed: currentPage > 0
                  ? () => controller.previousPage()
                  : null,
            ),
            Text(
              '${currentPage + 1} / $totalPages',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next_rounded),
              onPressed: currentPage < totalPages - 1
                  ? () => controller.nextPage()
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: () => controller.zoomLevel =
                  (controller.zoomLevel + 0.25).clamp(0.5, 5.0),
            ),
          ],
        ),
      ),
    );
  }
}