// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// import '../../../shared/models/pdf_file_model.dart';
// import '../bloc/pdf_viewer_bloc.dart';
// import '../bloc/pdf_viewer_event.dart';
// import '../bloc/pdf_viewer_state.dart';
// import 'widgets/viewer_controls.dart';
// import 'widgets/bookmark_sheet.dart';

// class PdfViewerScreen extends StatelessWidget {
//   const PdfViewerScreen({super.key, required this.file});
//   final PdfFileModel file;

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (_) => PdfViewerBloc()..add(PdfViewerLoadEvent(file.path)),
//       child: _PdfViewerView(file: file),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Shell — owns ONLY the Overlay lifecycle. Never rebuilds after initState.
// // ─────────────────────────────────────────────────────────────────────────────
// class _PdfViewerView extends StatefulWidget {
//   const _PdfViewerView({required this.file});
//   final PdfFileModel file;

//   @override
//   State<_PdfViewerView> createState() => _PdfViewerViewState();
// }

// class _PdfViewerViewState extends State<_PdfViewerView> {
//   final _pdfViewerController = PdfViewerController();

//   // Overlay handles all chrome — completely detached from the PDF widget tree
//   OverlayEntry? _overlayEntry;

//   // ValueNotifiers drive the overlay without calling setState on this widget
//   final _showControls = ValueNotifier<bool>(true);
//   Timer? _hideTimer;

//   @override
//   void initState() {
//     super.initState();
//     _resetHideTimer();
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // Insert overlay once we have an Overlay in the tree
//     if (_overlayEntry == null) {
//       _overlayEntry = _buildOverlayEntry();
//       // Post-frame so Overlay is fully mounted
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         Overlay.of(context).insert(_overlayEntry!);
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _hideTimer?.cancel();
//     _overlayEntry?.remove();
//     _overlayEntry?.dispose();
//     _showControls.dispose();
//     _pdfViewerController.dispose();
//     super.dispose();
//   }

//   void _resetHideTimer() {
//     _hideTimer?.cancel();
//     _showControls.value = true;
//     _hideTimer = Timer(const Duration(seconds: 3), () {
//       if (mounted) _showControls.value = false;
//     });
//   }

//   void _onTap() {
//     _showControls.value = !_showControls.value;
//     if (_showControls.value) _resetHideTimer();
//   }

//   // ── Overlay entry: AppBar + bottom controls, fully independent of PDF ──────
//   OverlayEntry _buildOverlayEntry() {
//     return OverlayEntry(
//       // maintainState keeps the overlay alive even if controls are hidden
//       maintainState: true,
//       builder: (overlayContext) {
//         // Pull the bloc from the original context — overlay has no bloc ancestor
//         final bloc = context.read<PdfViewerBloc>();
//         final theme = Theme.of(context);

//         return BlocProvider.value(
//           value: bloc,
//           child: _ControlsOverlay(
//             file: widget.file,
//             controller: _pdfViewerController,
//             showControls: _showControls,
//             theme: theme,
//             onShowBookmarks: _showBookmarksSheet,
//           ),
//         );
//       },
//     );
//   }

//   void _showBookmarksSheet() {
//     final state = context.read<PdfViewerBloc>().state;
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
//       ),
//       builder: (_) => BlocProvider.value(
//         value: context.read<PdfViewerBloc>(),
//         child: BookmarkSheet(
//           bookmarkedPages: state.bookmarkedPages,
//           onJump: (page) {
//             _pdfViewerController.jumpToPage(page + 1);
//             Navigator.pop(context);
//           },
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This build method is called ONCE and never again.
//     // The Scaffold has no AppBar — it lives in the Overlay above.
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: _PdfBody(
//         file: widget.file,
//         controller: _pdfViewerController,
//         onTap: _onTap,
//         onPageChanged: _resetHideTimer,
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // PDF body — StatefulWidget so it is created once and NEVER rebuilt.
// // All BlocListener/BlocSelector work is done at leaf level inside.
// // ─────────────────────────────────────────────────────────────────────────────
// class _PdfBody extends StatefulWidget {
//   const _PdfBody({
//     required this.file,
//     required this.controller,
//     required this.onTap,
//     required this.onPageChanged,
//   });

//   final PdfFileModel file;
//   final PdfViewerController controller;
//   final VoidCallback onTap;
//   final VoidCallback onPageChanged;

//   @override
//   State<_PdfBody> createState() => _PdfBodyState();
// }

// class _PdfBodyState extends State<_PdfBody> {
//   // Track pointer position to distinguish tap vs scroll
//   Offset? _pointerDown;
//   bool _isNightMode = false;

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<PdfViewerBloc, PdfViewerState>(
//       // Only listen to night mode — the only thing that changes the PDF widget
//       listenWhen: (prev, curr) => prev.isNightMode != curr.isNightMode,
//       listener: (_, state) => setState(() => _isNightMode = state.isNightMode),
//       child: Listener(
//         // Listener sits OUTSIDE the gesture arena — it never competes with
//         // SfPdfViewer's internal GestureDetectors for scroll/pinch events.
//         behavior: HitTestBehavior.translucent,
//         onPointerDown: (e) => _pointerDown = e.localPosition,
//         onPointerUp: (e) {
//           if (_pointerDown == null) return;
//           final moved = (e.localPosition - _pointerDown!).distance;
//           if (moved < 12) widget.onTap(); // pure tap, not a scroll
//           _pointerDown = null;
//         },
//         onPointerCancel: (_) => _pointerDown = null,
//         child: RepaintBoundary(
//           // Isolates the PDF into its own compositing layer.
//           // Night-mode ColorFilter repaints only this layer, not the overlay.
//           child: _maybeDark(
//             RepaintBoundary(
//               child: SfPdfViewer.file(
//                 widget.file.file,
//                 controller: widget.controller,
//                 onPageChanged: (details) {
//                   widget.onPageChanged();
//                   context.read<PdfViewerBloc>().add(
//                         PdfViewerPageChangedEvent(details.newPageNumber - 1));
//                 },
//                 onDocumentLoaded: (details) {
//                   context.read<PdfViewerBloc>().add(
//                         PdfViewerDocumentLoadedEvent(
//                             details.document.pages.count));
//                 },
//                 initialPageNumber: widget.file.lastOpenedPage + 1,
//                 pageSpacing: 4,
//                 canShowScrollHead: true,
//                 canShowScrollStatus: false,
//                 enableDoubleTapZooming: true,
//                 // pan mode: no text-selection overlay to fight with scroll
//                 interactionMode: PdfInteractionMode.pan,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _maybeDark(Widget child) {
//     if (!_isNightMode) return child;
//     return ColorFiltered(
//       colorFilter: const ColorFilter.matrix([
//         -1, 0, 0, 0, 255,
//         0, -1, 0, 0, 255,
//         0, 0, -1, 0, 255,
//         0,  0, 0, 1,   0,
//       ]),
//       child: child,
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Controls overlay — lives in Flutter's Overlay, completely above the PDF tree.
// // Rebuilds freely without touching the PDF widget at all.
// // ─────────────────────────────────────────────────────────────────────────────
// class _ControlsOverlay extends StatelessWidget {
//   const _ControlsOverlay({
//     required this.file,
//     required this.controller,
//     required this.showControls,
//     required this.theme,
//     required this.onShowBookmarks,
//   });

//   final PdfFileModel file;
//   final PdfViewerController controller;
//   final ValueNotifier<bool> showControls;
//   final ThemeData theme;
//   final VoidCallback onShowBookmarks;

//   @override
//   Widget build(BuildContext context) {
//     return ValueListenableBuilder<bool>(
//       valueListenable: showControls,
//       builder: (context, visible, _) {
//         return Stack(
//           children: [
//             // ── AppBar ──────────────────────────────────────────────────────
//             AnimatedPositioned(
//               duration: const Duration(milliseconds: 220),
//               curve: Curves.easeInOut,
//               top: visible
//                   ? 0
//                   : -(kToolbarHeight + MediaQuery.of(context).padding.top),
//               left: 0,
//               right: 0,
//               child: IgnorePointer(
//                 ignoring: !visible,
//                 child: _FakeAppBar(
//                   file: file,
//                   theme: theme,
//                   onShowBookmarks: onShowBookmarks,
//                 ),
//               ),
//             ),

//             // ── Bottom controls ─────────────────────────────────────────────
//             AnimatedPositioned(
//               duration: const Duration(milliseconds: 220),
//               curve: Curves.easeInOut,
//               bottom: visible ? 24.h : -80.h,
//               left: 0,
//               right: 0,
//               child: IgnorePointer(
//                 ignoring: !visible,
//                 child: BlocSelector<PdfViewerBloc, PdfViewerState, (int, int)>(
//                   selector: (s) => (s.currentPage, s.totalPages),
//                   builder: (context, pages) => ViewerControls(
//                     controller: controller,
//                     currentPage: pages.$1,
//                     totalPages: pages.$2,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Fake AppBar rendered inside the Overlay (real AppBar is on the Scaffold
// // which has no appBar to avoid the Scaffold rebuilding).
// // ─────────────────────────────────────────────────────────────────────────────
// class _FakeAppBar extends StatelessWidget {
//   const _FakeAppBar({
//     required this.file,
//     required this.theme,
//     required this.onShowBookmarks,
//   });

//   final PdfFileModel file;
//   final ThemeData theme;
//   final VoidCallback onShowBookmarks;

//   @override
//   Widget build(BuildContext context) {
//     final topPad = MediaQuery.of(context).padding.top;
//     final cs = theme.colorScheme;

//     return Material(
//       color: cs.surface,
//       elevation: 4,
//       child: Padding(
//         padding: EdgeInsets.only(top: topPad),
//         child: SizedBox(
//           height: kToolbarHeight,
//           child: Row(
//             children: [
//               BackButton(onPressed: () => Navigator.of(context).pop()),

//               // Title — only page counter rebuilds
//               Expanded(
//                 child: BlocSelector<PdfViewerBloc, PdfViewerState, (int, int)>(
//                   selector: (s) => (s.currentPage, s.totalPages),
//                   builder: (context, pages) => Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         file.name,
//                         style: theme.textTheme.bodyMedium
//                             ?.copyWith(fontWeight: FontWeight.w600),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       if (pages.$2 > 0)
//                         Text(
//                           'Page ${pages.$1 + 1} of ${pages.$2}',
//                           style: theme.textTheme.labelSmall,
//                         ),
//                     ],
//                   ),
//                 ),
//               ),

//               // Bookmark button — only rebuilds when bookmark flag changes
//               BlocSelector<PdfViewerBloc, PdfViewerState, (bool, int)>(
//                 selector: (s) => (s.isCurrentPageBookmarked, s.currentPage),
//                 builder: (context, data) => IconButton(
//                   icon: Icon(
//                     data.$1
//                         ? Icons.bookmark_rounded
//                         : Icons.bookmark_outline_rounded,
//                     color: data.$1 ? cs.primary : null,
//                   ),
//                   onPressed: () => context
//                       .read<PdfViewerBloc>()
//                       .add(PdfViewerToggleBookmarkEvent(data.$2)),
//                 ),
//               ),

//               IconButton(
//                 icon: const Icon(Icons.list_rounded),
//                 onPressed: onShowBookmarks,
//               ),

//               BlocSelector<PdfViewerBloc, PdfViewerState, bool>(
//                 selector: (s) => s.isNightMode,
//                 builder: (context, isNight) => IconButton(
//                   icon: Icon(isNight
//                       ? Icons.wb_sunny_rounded
//                       : Icons.nights_stay_rounded),
//                   onPressed: () => context
//                       .read<PdfViewerBloc>()
//                       .add(const PdfViewerToggleNightModeEvent()),
//                 ),
//               ),

//               IconButton(
//                 icon: const Icon(Icons.share_rounded),
//                 onPressed: () => context
//                     .read<PdfViewerBloc>()
//                     .add(const PdfViewerShareEvent()),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }