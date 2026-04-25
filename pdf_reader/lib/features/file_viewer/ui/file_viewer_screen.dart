import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/services/reading_progress_service.dart';
import '../../../features/pdf_viewer/bloc/pdf_viewer_bloc.dart';
import '../../../features/pdf_viewer/bloc/pdf_viewer_event.dart';
import '../../../features/pdf_viewer/bloc/pdf_viewer_state.dart';
import '../../../features/pdf_viewer/ui/widgets/bookmark_sheet.dart';
import '../../../features/pdf_viewer/ui/widgets/viewer_controls.dart';
import '../../../shared/models/pdf_file_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FileViewerScreen — ONE screen, ONE AppBar, every file type.
//
// Visual rule: every format uses the same PDF-style chrome:
//   • Black scaffold background
//   • White page card(s) with drop-shadow floating on the black
//   • Same AppBar, same loader (_PageLoader), same error (_PageError)
//
// The two shared building blocks used by EVERY non-PDF format:
//   _PageCard       — white rectangle with shadow
//   _PageScrollView — Scrollbar > SingleChildScrollView > _PageCard
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// Entry point
// ══════════════════════════════════════════════════════════════════════════════
class FileViewerScreen extends StatelessWidget {
  const FileViewerScreen({super.key, required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) {
    if (file.fileType == FileType.pdf) {
      return BlocProvider(
        create: (_) => PdfViewerBloc()..add(PdfViewerLoadEvent(file.path)),
        child: _UnifiedScaffold(file: file),
      );
    }
    return _UnifiedScaffold(file: file);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Scaffold — identical for every format
// ══════════════════════════════════════════════════════════════════════════════
class _UnifiedScaffold extends StatefulWidget {
  const _UnifiedScaffold({required this.file});
  final PdfFileModel file;

  @override
  State<_UnifiedScaffold> createState() => _UnifiedScaffoldState();
}

class _UnifiedScaffoldState extends State<_UnifiedScaffold> {
  final _pdfController = PdfViewerController();
  double _fontSize = 14.0;
  static const _minFont = 10.0;
  static const _maxFont = 28.0;

  bool get _isPdf => widget.file.fileType == FileType.pdf;
  bool get _hasTextControls =>
      widget.file.fileType == FileType.txt ||
      widget.file.fileType == FileType.csv ||
      widget.file.fileType == FileType.docx;

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _showBookmarkSheet() {
    final state = context.read<PdfViewerBloc>().state;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<PdfViewerBloc>(),
        child: BookmarkSheet(
          bookmarkedPages: state.bookmarkedPages,
          onJump: (page) {
            _pdfController.jumpToPage(page + 1);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  String _subtitle() => switch (widget.file.fileType) {
        FileType.txt   => 'Text file',
        FileType.csv   => 'CSV file',
        FileType.xlsx  => 'Spreadsheet',
        FileType.docx  => 'Word document',
        FileType.pptx  => 'Presentation',
        FileType.image => 'Image',
        FileType.pdf   => '',
        _              => widget.file.extension.toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black, // same for every format
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        elevation: 3,
        shadowColor: cs.shadow.withOpacity(0.12),
        titleSpacing: 0,
        title: _isPdf
            ? BlocSelector<PdfViewerBloc, PdfViewerState, (int, int)>(
                selector: (s) => (s.currentPage, s.totalPages),
                builder: (_, pages) => _AppBarTitle(
                  name: widget.file.name,
                  subtitle: pages.$2 > 0
                      ? 'Page ${pages.$1 + 1} of ${pages.$2}'
                      : '',
                  theme: theme,
                ),
              )
            : _AppBarTitle(
                name: widget.file.name,
                subtitle: _subtitle(),
                theme: theme,
              ),
        actions: [
          if (_isPdf) ...[
            BlocSelector<PdfViewerBloc, PdfViewerState, (bool, int)>(
              selector: (s) => (s.isCurrentPageBookmarked, s.currentPage),
              builder: (ctx, data) => IconButton(
                icon: Icon(
                  data.$1
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: data.$1 ? cs.primary : null,
                ),
                tooltip: data.$1 ? 'Remove bookmark' : 'Bookmark page',
                onPressed: () => ctx
                    .read<PdfViewerBloc>()
                    .add(PdfViewerToggleBookmarkEvent(data.$2)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list_rounded),
              tooltip: 'Bookmarks',
              onPressed: _showBookmarkSheet,
            ),
            BlocSelector<PdfViewerBloc, PdfViewerState, bool>(
              selector: (s) => s.isNightMode,
              builder: (ctx, isNight) => IconButton(
                icon: Icon(isNight
                    ? Icons.wb_sunny_rounded
                    : Icons.nights_stay_rounded),
                tooltip: isNight ? 'Day mode' : 'Night mode',
                onPressed: () => ctx
                    .read<PdfViewerBloc>()
                    .add(const PdfViewerToggleNightModeEvent()),
              ),
            ),
          ],
          if (_hasTextControls) ...[
            IconButton(
              icon: const Icon(Icons.text_decrease_rounded),
              tooltip: 'Smaller text',
              onPressed: _fontSize > _minFont
                  ? () => setState(() =>
                      _fontSize = (_fontSize - 2).clamp(_minFont, _maxFont))
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.text_increase_rounded),
              tooltip: 'Larger text',
              onPressed: _fontSize < _maxFont
                  ? () => setState(() =>
                      _fontSize = (_fontSize + 2).clamp(_minFont, _maxFont))
                  : null,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share',
            onPressed: _isPdf
                ? () => context
                    .read<PdfViewerBloc>()
                    .add(const PdfViewerShareEvent())
                : () => Share.shareXFiles(
                      [XFile(widget.file.path)],
                      subject: widget.file.name,
                    ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() => switch (widget.file.fileType) {
        FileType.pdf =>
          _PdfBody(file: widget.file, controller: _pdfController),
        FileType.txt || FileType.csv =>
          _PlainTextBody(file: widget.file, fontSize: _fontSize),
        FileType.xlsx  => _ExcelBody(file: widget.file),
        FileType.docx  => _DocxBody(file: widget.file, fontSize: _fontSize),
        FileType.pptx  => _PptxBody(file: widget.file),
        FileType.image => _ImageBody(file: widget.file),
        _              => _UnknownBody(file: widget.file),
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// AppBar title (shared)
// ══════════════════════════════════════════════════════════════════════════════
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({
    required this.name,
    required this.subtitle,
    required this.theme,
  });
  final String name, subtitle;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
            ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// _PageCard  — white rectangle with shadow, mimics a PDF page.
//              Used by every non-PDF body widget.
// ══════════════════════════════════════════════════════════════════════════════
class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.child,
    this.horizontalPadding = 20.0,
    this.verticalPadding = 24.0,
  });
  final Widget child;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(4)),
          boxShadow: [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// _PageScrollView — Scrollbar > bounce-scroll > _PageCard.
//                   THE unified body structure for TXT, CSV, DOCX, XLSX, PPTX.
// ══════════════════════════════════════════════════════════════════════════════
class _PageScrollView extends StatelessWidget {
  const _PageScrollView({
    required this.child,
    this.horizontalPadding = 20.0,
    this.verticalPadding = 24.0,
  });
  final Widget child;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) => Scrollbar(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: _PageCard(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            child: child,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers — loader and error also use the page-card look
// ══════════════════════════════════════════════════════════════════════════════
class _PageLoader extends StatelessWidget {
  const _PageLoader();

  @override
  Widget build(BuildContext context) => Center(
        child: _PageCard(
          child: const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF1A73E8)),
            ),
          ),
        ),
      );
}

class _PageError extends StatelessWidget {
  const _PageError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: _PageCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: Color(0xFFD32F2F)),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                    color: Color(0xFFD32F2F), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PDF BODY  (unchanged — uses SfPdfViewer which already renders PDF pages)
// ══════════════════════════════════════════════════════════════════════════════
class _PdfBody extends StatefulWidget {
  const _PdfBody({required this.file, required this.controller});
  final PdfFileModel file;
  final PdfViewerController controller;

  @override
  State<_PdfBody> createState() => _PdfBodyState();
}

class _PdfBodyState extends State<_PdfBody> {
  bool _isNightMode = false;

  @override
  Widget build(BuildContext context) => BlocListener<PdfViewerBloc, PdfViewerState>(
        listenWhen: (p, c) => p.isNightMode != c.isNightMode,
        listener: (_, s) => setState(() => _isNightMode = s.isNightMode),
        child: Stack(
          children: [
            RepaintBoundary(
              child: _nightWrap(
                RepaintBoundary(
                  child: SfPdfViewer.file(
                    widget.file.file,
                    controller: widget.controller,
                    onPageChanged: (d) => context
                        .read<PdfViewerBloc>()
                        .add(PdfViewerPageChangedEvent(d.newPageNumber - 1)),
                    onDocumentLoaded: (d) => context
                        .read<PdfViewerBloc>()
                        .add(PdfViewerDocumentLoadedEvent(
                            d.document.pages.count)),
                    initialPageNumber: widget.file.lastOpenedPage + 1,
                    pageSpacing: 4,
                    canShowScrollHead: true,
                    canShowScrollStatus: false,
                    enableDoubleTapZooming: true,
                    interactionMode: PdfInteractionMode.pan,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24.h,
              child: BlocSelector<PdfViewerBloc, PdfViewerState, (int, int)>(
                selector: (s) => (s.currentPage, s.totalPages),
                builder: (_, pages) => ViewerControls(
                  controller: widget.controller,
                  currentPage: pages.$1,
                  totalPages: pages.$2,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _nightWrap(Widget child) => _isNightMode
      ? ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -1, 0, 0, 0, 255,
            0, -1, 0, 0, 255,
            0, 0, -1, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        )
      : child;
}

// ══════════════════════════════════════════════════════════════════════════════
// TXT / CSV  →  _PageScrollView > SelectableText
// ══════════════════════════════════════════════════════════════════════════════
class _PlainTextBody extends StatefulWidget {
  const _PlainTextBody({required this.file, required this.fontSize});
  final PdfFileModel file;
  final double fontSize;

  @override
  State<_PlainTextBody> createState() => _PlainTextBodyState();
}

class _PlainTextBodyState extends State<_PlainTextBody> {
  late final Future<String> _future = File(widget.file.path).readAsString();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _PageLoader();
          }
          if (snap.hasError) return _PageError('${snap.error}');
          return _PageScrollView(
            child: SelectableText(
              snap.data ?? '',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: widget.fontSize,
                height: 1.65,
                color: Colors.black87,
              ),
            ),
          );
        },
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// DOCX  →  _PageScrollView > Column of paragraphs
// ══════════════════════════════════════════════════════════════════════════════
class _DocxBody extends StatefulWidget {
  const _DocxBody({required this.file, required this.fontSize});
  final PdfFileModel file;
  final double fontSize;

  @override
  State<_DocxBody> createState() => _DocxBodyState();
}

class _DocxBodyState extends State<_DocxBody> {
  late final Future<List<_Para>> _future = _parse();

  Future<List<_Para>> _parse() async {
    final bytes = await File(widget.file.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('Not a valid DOCX file'),
    );
    final xml =
        utf8.decode(docFile.content as List<int>, allowMalformed: true);
    final paras = <_Para>[];

    for (final m
        in RegExp(r'<w:p[ >].*?</w:p>', dotAll: true).allMatches(xml)) {
      final px = m.group(0)!;
      final styleVal =
          RegExp(r'<w:pStyle[^>]+w:val="([^"]+)"')
                  .firstMatch(px)
                  ?.group(1)
                  ?.toLowerCase() ??
              '';
      final runs = RegExp(r'<w:r[ >].*?</w:r>', dotAll: true)
          .allMatches(px)
          .map((r) => r.group(0)!)
          .toList();
      final isBold = runs.isNotEmpty &&
          runs.every((r) => r.contains('<w:b/>') || r.contains('<w:b '));
      final text = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
          .allMatches(px)
          .map((t) => t.group(1) ?? '')
          .join('');
      if (text.trim().isEmpty) continue;

      _ParaStyle style = _ParaStyle.body;
      if (styleVal.contains('heading1') || styleVal == 'title') {
        style = _ParaStyle.h1;
      } else if (styleVal.contains('heading2') || styleVal == 'subtitle') {
        style = _ParaStyle.h2;
      } else if (styleVal.contains('heading3')) {
        style = _ParaStyle.h3;
      } else if (isBold && text.trim().length <= 80) {
        style = _ParaStyle.h2;
      }
      paras.add(_Para(text: text, style: style));
    }

    if (paras.isEmpty) throw Exception('No text found in this DOCX file');
    return paras;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_Para>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _PageLoader();
          }
          if (snap.hasError) return _PageError('${snap.error}');

          final base = widget.fontSize;
          return _PageScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: snap.data!.map((p) {
                final style = switch (p.style) {
                  _ParaStyle.h1 => TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: base * 1.55,
                      color: Colors.black87,
                      height: 1.4),
                  _ParaStyle.h2 => TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: base * 1.25,
                      color: Colors.black87,
                      height: 1.4),
                  _ParaStyle.h3 => TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: base * 1.1,
                      color: Colors.black87,
                      height: 1.4),
                  _ParaStyle.body => TextStyle(
                      fontSize: base, color: Colors.black87, height: 1.65),
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(p.text, style: style),
                );
              }).toList(),
            ),
          );
        },
      );
}

enum _ParaStyle { h1, h2, h3, body }

class _Para {
  const _Para({required this.text, required this.style});
  final String text;
  final _ParaStyle style;
}

// ══════════════════════════════════════════════════════════════════════════════
// XLSX  →  _PageScrollView > (tabs) + DataTable  (all inside one page card)
// ══════════════════════════════════════════════════════════════════════════════
class _ExcelBody extends StatefulWidget {
  const _ExcelBody({required this.file});
  final PdfFileModel file;

  @override
  State<_ExcelBody> createState() => _ExcelBodyState();
}

class _ExcelBodyState extends State<_ExcelBody> {
  late final Future<excel_pkg.Excel> _future = _load();
  int _sheetIndex = 0;

  Future<excel_pkg.Excel> _load() async {
    final bytes = await File(widget.file.path).readAsBytes();
    return excel_pkg.Excel.decodeBytes(bytes);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<excel_pkg.Excel>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _PageLoader();
          }
          if (snap.hasError || snap.data == null) {
            return _PageError('Cannot read spreadsheet: ${snap.error}');
          }

          final xls = snap.data!;
          final sheets = xls.tables.keys.toList();
          if (sheets.isEmpty) return const _PageError('No sheets found');
          if (_sheetIndex >= sheets.length) _sheetIndex = 0;
          final rows = xls.tables[sheets[_sheetIndex]]!.rows;

          // Tabs + table live inside ONE _PageScrollView — same as TXT/DOCX
          return _PageScrollView(
            horizontalPadding: 0,
            verticalPadding: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sheet tabs
                if (sheets.length > 1)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: List.generate(sheets.length, (i) {
                        final sel = i == _sheetIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _sheetIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1A73E8)
                                  : const Color(0xFFE8F0FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              sheets[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF1A73E8),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                if (sheets.length > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Divider(height: 1, color: Color(0xFFDDDDDD)),
                  ),

                // Table
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Sheet is empty',
                          style: TextStyle(color: Colors.black54)),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF1F3F4)),
                      border: TableBorder.all(
                          color: const Color(0xFFDDDDDD), width: 0.5),
                      columns: rows.first
                          .map((c) => DataColumn(
                                label: Text(
                                  c?.value?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ))
                          .toList(),
                      rows: rows.skip(1).map((row) {
                        return DataRow(
                          cells: row
                              .map((c) => DataCell(Text(
                                    c?.value?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black87),
                                  )))
                              .toList(),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PPTX  →  _PageScrollView > slide content
//           + floating prev/next pill (same style as PDF's ViewerControls)
// ══════════════════════════════════════════════════════════════════════════════
class _PptxBody extends StatefulWidget {
  const _PptxBody({required this.file});
  final PdfFileModel file;

  @override
  State<_PptxBody> createState() => _PptxBodyState();
}

class _PptxBodyState extends State<_PptxBody> {
  late final Future<List<List<String>>> _future = _parse();
  int _slide = 0;

  Future<List<List<String>>> _parse() async {
    final bytes = await File(widget.file.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') &&
            f.name.endsWith('.xml') &&
            !f.name.contains('_rels'))
        .toList()
      ..sort((a, b) {
        int n(String s) =>
            int.tryParse(
                    RegExp(r'slide(\d+)\.xml').firstMatch(s)?.group(1) ??
                        '0') ??
            0;
        return n(a.name).compareTo(n(b.name));
      });

    if (slideFiles.isEmpty) throw Exception('No slides found');

    return slideFiles.map((f) {
      final xml =
          utf8.decode(f.content as List<int>, allowMalformed: true);
      final lines = RegExp(r'<a:t[^>]*>(.*?)<\/a:t>', dotAll: true)
          .allMatches(xml)
          .map((m) => m.group(1)?.trim() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      return lines.isEmpty ? <String>['(empty slide)'] : lines;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<String>>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _PageLoader();
          }
          if (snap.hasError) return _PageError('${snap.error}');

          final slides = snap.data!;
          final total = slides.length;
          final texts = slides[_slide];

          return Stack(
            children: [
              // Slide content — same _PageScrollView as TXT / DOCX / XLSX
              _PageScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slide badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Slide ${_slide + 1} of $total',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A73E8)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    if (texts.isNotEmpty)
                      SelectableText(
                        texts.first,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            color: Colors.black87,
                            height: 1.35),
                      ),

                    // Body lines
                    if (texts.length > 1) ...[
                      const SizedBox(height: 14),
                      ...texts.skip(1).map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(
                              line,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.6),
                            ),
                          )),
                    ],

                    // Bottom padding so nav pill doesn't cover content
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Floating nav pill — matches PDF's ViewerControls style
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 10,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: _slide > 0
                            ? () => setState(() => _slide--)
                            : null,
                      ),
                      Text(
                        '${_slide + 1} / $total',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 20),
                        onPressed: _slide < total - 1
                            ? () => setState(() => _slide++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// IMAGE  →  white _PageCard on black background, pinch-zoom inside
// ══════════════════════════════════════════════════════════════════════════════
class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) => _PageScrollView(
        horizontalPadding: 12,
        verticalPadding: 16,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8.0,
          child: Image.file(
            File(file.path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const _PageError('Cannot display image'),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// UNKNOWN  →  centred page card
// ══════════════════════════════════════════════════════════════════════════════
class _UnknownBody extends StatelessWidget {
  const _UnknownBody({required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) => Center(
        child: _PageCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded,
                  size: 64, color: Color(0x55000000)),
              const SizedBox(height: 16),
              Text(
                'Cannot preview .${file.extension.toLowerCase()} files',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'You can share it to open with another app.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}