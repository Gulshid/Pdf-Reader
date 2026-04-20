// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../shared/models/ pdf_file_model.dart';
import '../bloc/pdf_viewer_bloc.dart';
import '../bloc/pdf_viewer_event.dart';
import '../bloc/pdf_viewer_state.dart';
import 'widgets/viewer_controls.dart';
import 'widgets/bookmark_sheet.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PdfViewerBloc()
        ..add(PdfViewerLoadEvent(file.path)),
      child: _PdfViewerView(file: file),
    );
  }
}

class _PdfViewerView extends StatefulWidget {
  const _PdfViewerView({required this.file});
  final PdfFileModel file;

  @override
  State<_PdfViewerView> createState() => _PdfViewerViewState();
}

class _PdfViewerViewState extends State<_PdfViewerView> {
  final _pdfViewerController = PdfViewerController();
  final _searchController = PdfTextSearchResult();

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<PdfViewerBloc, PdfViewerState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.file.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (state.totalPages > 0)
                  Text(
                    'Page ${state.currentPage + 1} of ${state.totalPages}',
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  state.isCurrentPageBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: state.isCurrentPageBookmarked
                      ? theme.colorScheme.primary
                      : null,
                ),
                onPressed: () => context
                    .read<PdfViewerBloc>()
                    .add(PdfViewerToggleBookmarkEvent(state.currentPage)),
              ),
              IconButton(
                icon: const Icon(Icons.list_rounded),
                onPressed: () => _showBookmarks(context, state),
              ),
              IconButton(
                icon: Icon(
                  state.isNightMode
                      ? Icons.wb_sunny_rounded
                      : Icons.nights_stay_rounded,
                ),
                onPressed: () => context
                    .read<PdfViewerBloc>()
                    .add(const PdfViewerToggleNightModeEvent()),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () => context
                    .read<PdfViewerBloc>()
                    .add(const PdfViewerShareEvent()),
              ),
            ],
          ),
          body: Stack(
            children: [
              ColorFiltered(
                colorFilter: state.isNightMode
                    ? const ColorFilter.matrix([
                        -1, 0, 0, 0, 255,
                        0, -1, 0, 0, 255,
                        0, 0, -1, 0, 255,
                        0, 0, 0, 1, 0,
                      ])
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: SfPdfViewer.file(
                  widget.file.file,
                  controller: _pdfViewerController,
                  onPageChanged: (details) => context
                      .read<PdfViewerBloc>()
                      .add(PdfViewerPageChangedEvent(details.newPageNumber - 1)),
                  onDocumentLoaded: (details) => context
                      .read<PdfViewerBloc>()
                      .add(PdfViewerPageChangedEvent(0)),
                  initialPageNumber: widget.file.lastOpenedPage + 1,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  enableDoubleTapZooming: true,
                ),
              ),
              Positioned(
                bottom: 16.h,
                left: 0,
                right: 0,
                child: ViewerControls(
                  controller: _pdfViewerController,
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBookmarks(BuildContext context, PdfViewerState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<PdfViewerBloc>(),
        child: BookmarkSheet(
          bookmarkedPages: state.bookmarkedPages,
          onJump: (page) {
            _pdfViewerController.jumpToPage(page + 1);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}