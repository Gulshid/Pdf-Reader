// ignore_for_file: unused_element_parameter

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

import '../../../features/pdf_viewer/bloc/pdf_viewer_bloc.dart';
import '../../../features/pdf_viewer/bloc/pdf_viewer_event.dart';
import '../../../features/pdf_viewer/bloc/pdf_viewer_state.dart';
import '../../../features/pdf_viewer/ui/widgets/bookmark_sheet.dart';
import '../../../features/pdf_viewer/ui/widgets/viewer_controls.dart';
import '../../../shared/models/pdf_file_model.dart';

class FileViewerScreen extends StatelessWidget {
  const FileViewerScreen({super.key, required this.file});
  final PdfFileModel file;

  static FileType _sniffType(PdfFileModel file) {
    final declared = file.fileType;
    if (declared != FileType.unknown) return declared;
    try {
      final f = file.file;
      if (!f.existsSync()) return FileType.unknown;
      final len = f.lengthSync();
      if (len < 4) return FileType.unknown;
      final header = f.readAsBytesSync().sublist(0, 8.clamp(0, len));
      if (header[0] == 0x25 && header[1] == 0x50 && header[2] == 0x44 && header[3] == 0x46) return FileType.pdf;
      if (header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04) {
        try {
          final archive = ZipDecoder().decodeBytes(f.readAsBytesSync());
          final names = archive.files.map((e) => e.name).toList();
          if (names.any((n) => n.startsWith('word/'))) return FileType.docx;
          if (names.any((n) => n.startsWith('xl/'))) return FileType.xlsx;
          if (names.any((n) => n.startsWith('ppt/'))) return FileType.pptx;
        } catch (_) {}
      }
    } catch (_) {}
    return FileType.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveType = _sniffType(file);
    if (effectiveType == FileType.pdf) {
      return BlocProvider(
        create: (_) => PdfViewerBloc()..add(PdfViewerLoadEvent(file.path)),
        child: _UnifiedScaffold(file: file),
      );
    }
    return _UnifiedScaffold(file: file);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Scaffold
// ══════════════════════════════════════════════════════════════════════════════
class _UnifiedScaffold extends StatefulWidget {
  const _UnifiedScaffold({required this.file});
  final PdfFileModel file;
  @override
  State<_UnifiedScaffold> createState() => _UnifiedScaffoldState();
}

class _UnifiedScaffoldState extends State<_UnifiedScaffold> {
  final _pdfController = PdfViewerController();
  double _fontSize = 15.0;
  static const _minFont = 10.0;
  static const _maxFont = 30.0;

  FileType _resolveFileType() {
    final declared = widget.file.fileType;
    if (declared != FileType.unknown) return declared;
    try {
      final f = widget.file.file;
      if (!f.existsSync()) return FileType.unknown;
      final header = f.readAsBytesSync().sublist(0, 8.clamp(0, f.lengthSync()));
      if (header.length >= 4 && header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04) {
        try {
          final archive = ZipDecoder().decodeBytes(f.readAsBytesSync());
          final names = archive.files.map((e) => e.name).toList();
          if (names.any((n) => n.startsWith('word/'))) return FileType.docx;
          if (names.any((n) => n.startsWith('xl/'))) return FileType.xlsx;
          if (names.any((n) => n.startsWith('ppt/'))) return FileType.pptx;
        } catch (_) {}
        return FileType.unknown;
      }
      if (header.length >= 4 && header[0] == 0x25 && header[1] == 0x50 && header[2] == 0x44 && header[3] == 0x46) return FileType.pdf;
      if (header.length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) return FileType.image;
      if (header.length >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) return FileType.image;
    } catch (_) {}
    return FileType.unknown;
  }

  bool get _isPdf => _resolveFileType() == FileType.pdf;
  bool get _hasTextControls {
    final t = _resolveFileType();
    return t == FileType.txt || t == FileType.csv || t == FileType.docx;
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _showBookmarkSheet() {
    if (!_isPdf) return;
    final state = context.read<PdfViewerBloc>().state;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => BlocProvider.value(
        value: context.read<PdfViewerBloc>(),
        child: BookmarkSheet(
          bookmarkedPages: state.bookmarkedPages,
          onJump: (page) { _pdfController.jumpToPage(page + 1); Navigator.pop(context); },
        ),
      ),
    );
  }

  String _subtitle() => switch (_resolveFileType()) {
    FileType.txt   => 'Plain Text',
    FileType.csv   => 'Spreadsheet CSV',
    FileType.xlsx  => 'Excel Spreadsheet',
    FileType.docx  => 'Word Document',
    FileType.pptx  => 'PowerPoint Presentation',
    FileType.image => 'Image',
    FileType.pdf   => 'PDF Document',
    _              => widget.file.extension.toUpperCase(),
  };

  Color _typeColor() => switch (_resolveFileType()) {
    FileType.pdf   => const Color(0xFFE53935),
    FileType.docx  => const Color(0xFF1565C0),
    FileType.xlsx  => const Color(0xFF2E7D32),
    FileType.csv   => const Color(0xFF00897B),
    FileType.pptx  => const Color(0xFFE65100),
    FileType.txt   => const Color(0xFF546E7A),
    FileType.image => const Color(0xFF6A1B9A),
    _              => const Color(0xFF455A64),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final typeColor = _typeColor();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111418) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: typeColor.withOpacity(0.25)),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp),
          color: cs.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: _isPdf
            ? BlocSelector<PdfViewerBloc, PdfViewerState, (int, int)>(
                selector: (s) => (s.currentPage, s.totalPages),
                builder: (_, pages) => _AppBarTitle(
                  name: widget.file.name,
                  subtitle: pages.$2 > 0 ? 'Page ${pages.$1 + 1} of ${pages.$2}' : _subtitle(),
                  typeColor: typeColor, theme: theme,
                ),
              )
            : _AppBarTitle(name: widget.file.name, subtitle: _subtitle(), typeColor: typeColor, theme: theme),
        actions: [
          if (_isPdf) ...[
            BlocSelector<PdfViewerBloc, PdfViewerState, (bool, int)>(
              selector: (s) => (s.isCurrentPageBookmarked, s.currentPage),
              builder: (ctx, data) => _AppBarAction(
                icon: data.$1 ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: data.$1 ? typeColor : null,
                tooltip: data.$1 ? 'Remove bookmark' : 'Bookmark page',
                onPressed: () => ctx.read<PdfViewerBloc>().add(PdfViewerToggleBookmarkEvent(data.$2)),
              ),
            ),
            _AppBarAction(icon: Icons.list_rounded, tooltip: 'Bookmarks', onPressed: _showBookmarkSheet),
            BlocSelector<PdfViewerBloc, PdfViewerState, bool>(
              selector: (s) => s.isNightMode,
              builder: (ctx, isNight) => _AppBarAction(
                icon: isNight ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                tooltip: isNight ? 'Day mode' : 'Night mode',
                onPressed: () => ctx.read<PdfViewerBloc>().add(const PdfViewerToggleNightModeEvent()),
              ),
            ),
          ],
          if (_hasTextControls) ...[
            _AppBarAction(
              icon: Icons.text_decrease_rounded, tooltip: 'Smaller text',
              onPressed: _fontSize > _minFont
                  ? () => setState(() => _fontSize = (_fontSize - 2).clamp(_minFont, _maxFont))
                  : null,
            ),
            _AppBarAction(
              icon: Icons.text_increase_rounded, tooltip: 'Larger text',
              onPressed: _fontSize < _maxFont
                  ? () => setState(() => _fontSize = (_fontSize + 2).clamp(_minFont, _maxFont))
                  : null,
            ),
          ],
          _AppBarAction(
            icon: Icons.share_rounded, tooltip: 'Share',
            onPressed: _isPdf
                ? () => context.read<PdfViewerBloc>().add(const PdfViewerShareEvent())
                : () => Share.shareXFiles([XFile(widget.file.path)], subject: widget.file.name),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final fileType = _resolveFileType();
    return switch (fileType) {
      FileType.pdf   => _PdfBody(file: widget.file, controller: _pdfController),
      FileType.txt || FileType.csv => _PlainTextBody(file: widget.file, fontSize: _fontSize),
      FileType.xlsx  => _ExcelBody(file: widget.file),
      FileType.docx  => _DocxBody(file: widget.file, fontSize: _fontSize),
      FileType.pptx  => _PptxBody(file: widget.file),
      FileType.image => _ImageBody(file: widget.file),
      _              => _UnknownBody(file: widget.file),
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AppBar helpers
// ══════════════════════════════════════════════════════════════════════════════
class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.name, required this.subtitle, required this.typeColor, required this.theme});
  final String name, subtitle;
  final Color typeColor;
  final ThemeData theme;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      if (subtitle.isNotEmpty)
        Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(color: typeColor, fontWeight: FontWeight.w500), maxLines: 1),
    ],
  );
}

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({required this.icon, required this.tooltip, this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon, size: 20.sp, color: color ?? cs.onSurface),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared page chrome
// ══════════════════════════════════════════════════════════════════════════════
class _PageCard extends StatelessWidget {
  const _PageCard({required this.child, this.horizontalPadding = 22.0, this.verticalPadding = 28.0});
  final Widget child;
  final double horizontalPadding, verticalPadding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6)),
        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
    child: child,
  );
}

class _PageScrollView extends StatelessWidget {
  const _PageScrollView({required this.child, this.horizontalPadding = 22.0, this.verticalPadding = 28.0, this.controller});
  final Widget child;
  final double horizontalPadding, verticalPadding;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    child: SingleChildScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      child: _PageCard(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding, child: child),
    ),
  );
}

class _PageLoader extends StatelessWidget {
  const _PageLoader();
  @override
  Widget build(BuildContext context) => Center(
    child: _PageCard(child: const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8), strokeWidth: 2.5)))),
  );
}

class _PageError extends StatelessWidget {
  const _PageError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: _PageCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFD32F2F)),
      const SizedBox(height: 14),
      Text(message, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13, height: 1.6), textAlign: TextAlign.center),
    ])),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PDF BODY
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
    child: Stack(children: [
      RepaintBoundary(child: _nightWrap(RepaintBoundary(child: SfPdfViewer.file(
        widget.file.file, controller: widget.controller,
        onPageChanged: (d) => context.read<PdfViewerBloc>().add(PdfViewerPageChangedEvent(d.newPageNumber - 1)),
        onDocumentLoaded: (d) => context.read<PdfViewerBloc>().add(PdfViewerDocumentLoadedEvent(d.document.pages.count)),
        initialPageNumber: widget.file.lastOpenedPage + 1,
        pageSpacing: 4, canShowScrollHead: true, canShowScrollStatus: false,
        enableDoubleTapZooming: true, interactionMode: PdfInteractionMode.pan,
      )))),
      Positioned(left: 0, right: 0, bottom: 24.h,
        child: BlocSelector<PdfViewerBloc, PdfViewerState, (int, int)>(
          selector: (s) => (s.currentPage, s.totalPages),
          builder: (_, pages) => ViewerControls(controller: widget.controller, currentPage: pages.$1, totalPages: pages.$2),
        ),
      ),
    ]),
  );
  Widget _nightWrap(Widget child) => _isNightMode
      ? ColorFiltered(colorFilter: const ColorFilter.matrix([-1,0,0,0,255,0,-1,0,0,255,0,0,-1,0,255,0,0,0,1,0]), child: child)
      : child;
}

// ══════════════════════════════════════════════════════════════════════════════
// TXT / CSV
// ══════════════════════════════════════════════════════════════════════════════
class _PlainTextBody extends StatefulWidget {
  const _PlainTextBody({required this.file, required this.fontSize});
  final PdfFileModel file;
  final double fontSize;
  @override
  State<_PlainTextBody> createState() => _PlainTextBodyState();
}

class _PlainTextBodyState extends State<_PlainTextBody> {
  late final Future<String> _future = _readText();

  Future<String> _readText() async {
    final bytes = await File(widget.file.path).readAsBytes();
    if (bytes.isEmpty) return '(empty file)';
    try { return utf8.decode(bytes); } catch (_) {}
    try { return latin1.decode(bytes); } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _future,
    builder: (_, snap) {
      if (snap.connectionState != ConnectionState.done) return const _PageLoader();
      if (snap.hasError) return _PageError('Cannot read file: ${snap.error}');
      final text = snap.data ?? '';
      final isCsv = widget.file.extension.toUpperCase() == 'CSV';
      if (isCsv) return _CsvTable(text: text);
      return _PageScrollView(child: SelectableText(text,
        style: TextStyle(fontFamily: 'monospace', fontSize: widget.fontSize, height: 1.7, color: Colors.black87, letterSpacing: 0.2)));
    },
  );
}

// ── CSV rendered as a proper scrollable table ─────────────────────────────────
class _CsvTable extends StatefulWidget {
  const _CsvTable({required this.text});
  final String text;
  @override
  State<_CsvTable> createState() => _CsvTableState();
}

class _CsvTableState extends State<_CsvTable> {
  late final List<List<String>> _rows;
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  @override
  void initState() { super.initState(); _rows = _parseCsv(widget.text); }
  @override
  void dispose() { _hScroll.dispose(); _vScroll.dispose(); super.dispose(); }

  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final fields = <String>[]; final cur = StringBuffer(); bool inQ = false;
      for (int i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          if (inQ && i + 1 < line.length && line[i + 1] == '"') { cur.write('"'); i++; }
          else { inQ = !inQ; }
        } else if (ch == ',' && !inQ) { fields.add(cur.toString()); cur.clear(); }
        else { cur.write(ch); }
      }
      fields.add(cur.toString()); rows.add(fields);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const _PageError('No data found in CSV file');
    final headers = _rows.first;
    final dataRows = _rows.skip(1).toList();
    return Scrollbar(controller: _vScroll, child: SingleChildScrollView(
      controller: _vScroll, physics: const BouncingScrollPhysics(),
      child: _PageCard(horizontalPadding: 0, verticalPadding: 0, child: Scrollbar(
        controller: _hScroll, scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(controller: _hScroll, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
          child: DataTable(
            headingRowHeight: 44, dataRowMinHeight: 38, dataRowMaxHeight: 52,
            columnSpacing: 20, horizontalMargin: 16,
            border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200)),
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)),
            columns: headers.map((h) => DataColumn(label: Text(h.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1A3A5C))))).toList(),
            rows: dataRows.asMap().entries.map((e) => DataRow(
              color: WidgetStateProperty.resolveWith((s) => e.key.isEven ? Colors.white : const Color(0xFFFAFBFC)),
              cells: e.value.map((cell) => DataCell(Text(cell.trim(),
                style: const TextStyle(fontSize: 12, color: Colors.black87)))).toList(),
            )).toList(),
          ),
        ),
      )),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DOCX
// ══════════════════════════════════════════════════════════════════════════════
class _DocxBody extends StatefulWidget {
  const _DocxBody({required this.file, required this.fontSize});
  final PdfFileModel file; final double fontSize;
  @override State<_DocxBody> createState() => _DocxBodyState();
}

class _DocxBodyState extends State<_DocxBody> {
  late final Future<List<_Para>> _future = _parse();

  Future<List<_Para>> _parse() async {
    final bytes = await File(widget.file.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere((f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('Not a valid DOCX file'));
    final rawContent = docFile.content;
    final contentBytes = rawContent is List<int> ? rawContent : List<int>.from(rawContent as List);
    final xml = utf8.decode(contentBytes, allowMalformed: true);
    final paras = <_Para>[];
    for (final m in RegExp(r'<w:p[ >].*?</w:p>', dotAll: true).allMatches(xml)) {
      final px = m.group(0)!;
      final styleVal = RegExp(r'<w:pStyle[^>]+w:val="([^"]+)"').firstMatch(px)?.group(1)?.toLowerCase() ?? '';
      final runs = RegExp(r'<w:r[ >].*?</w:r>', dotAll: true).allMatches(px).map((r) => r.group(0)!).toList();
      final isBold = runs.isNotEmpty && runs.every((r) => r.contains('<w:b/>') || r.contains('<w:b '));
      final rawText = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true).allMatches(px).map((t) => t.group(1) ?? '').join('');
      final text = rawText.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'");
      if (text.trim().isEmpty) continue;
      _ParaStyle style = _ParaStyle.body;
      if (styleVal.contains('heading1') || styleVal.contains('heading 1') || styleVal == 'title') { style = _ParaStyle.h1; }
      else if (styleVal.contains('heading2') || styleVal.contains('heading 2') || styleVal == 'subtitle') { style = _ParaStyle.h2; }
      else if (styleVal.contains('heading3') || styleVal.contains('heading 3')) { style = _ParaStyle.h3; }
      else if (isBold && text.trim().length <= 80) { style = _ParaStyle.h2; }
      paras.add(_Para(text: text, style: style));
    }
    if (paras.isEmpty) throw Exception('No readable text found in this DOCX file');
    return paras;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_Para>>(
    future: _future,
    builder: (_, snap) {
      if (snap.connectionState != ConnectionState.done) return const _PageLoader();
      if (snap.hasError) return _PageError('${snap.error}');
      final base = widget.fontSize;
      return _PageScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: snap.data!.map((p) {
        switch (p.style) {
          case _ParaStyle.h1:
            return Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(p.text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: base * 1.6, color: const Color(0xFF1A3A5C), height: 1.3)),
              const SizedBox(height: 6),
              Container(height: 3, width: 48, decoration: BoxDecoration(color: const Color(0xFF1A3A5C), borderRadius: BorderRadius.circular(2))),
            ]));
          case _ParaStyle.h2:
            return Padding(padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: SelectableText(p.text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: base * 1.25, color: const Color(0xFF2E6DA4), height: 1.35)));
          case _ParaStyle.h3:
            return Padding(padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: SelectableText(p.text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: base * 1.1, color: Colors.black87, height: 1.4)));
          case _ParaStyle.body:
            return Padding(padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText(p.text, style: TextStyle(fontSize: base, color: Colors.black87, height: 1.75)));
        }
      }).toList()));
    },
  );
}

enum _ParaStyle { h1, h2, h3, body }
class _Para { const _Para({required this.text, required this.style}); final String text; final _ParaStyle style; }

// ══════════════════════════════════════════════════════════════════════════════
// XLSX
// ══════════════════════════════════════════════════════════════════════════════
class _ExcelBody extends StatefulWidget {
  const _ExcelBody({required this.file});
  final PdfFileModel file;
  @override State<_ExcelBody> createState() => _ExcelBodyState();
}

class _ExcelBodyState extends State<_ExcelBody> {
  late final Future<excel_pkg.Excel> _future = _load();
  int _sheetIndex = 0;
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  Future<excel_pkg.Excel> _load() async {
    final bytes = await File(widget.file.path).readAsBytes();
    return excel_pkg.Excel.decodeBytes(bytes);
  }

  @override
  void dispose() { _hScroll.dispose(); _vScroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FutureBuilder<excel_pkg.Excel>(
    future: _future,
    builder: (_, snap) {
      if (snap.connectionState != ConnectionState.done) return const _PageLoader();
      if (snap.hasError || snap.data == null) return _PageError('Cannot read spreadsheet: ${snap.error}');
      final xls = snap.data!;
      final sheets = xls.tables.keys.toList();
      if (sheets.isEmpty) return const _PageError('No sheets found');
      if (_sheetIndex >= sheets.length) _sheetIndex = 0;
      final rows = xls.tables[sheets[_sheetIndex]]!.rows;

      return Column(children: [
        // Sheet tabs
        if (sheets.length > 1)
          Container(color: Colors.black, child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(children: sheets.asMap().entries.map((e) {
              final sel = e.key == _sheetIndex;
              return Padding(padding: EdgeInsets.only(right: 8.w), child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); setState(() => _sheetIndex = e.key); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF2E7D32) : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? const Color(0xFF2E7D32) : Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(e.value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ));
            }).toList()),
          )),

        // Table
        Expanded(child: rows.isEmpty
          ? const _PageError('This sheet is empty')
          : Scrollbar(controller: _vScroll, child: SingleChildScrollView(
              controller: _vScroll, physics: const BouncingScrollPhysics(),
              child: _PageCard(horizontalPadding: 0, verticalPadding: 0, child: Scrollbar(
                controller: _hScroll, scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(controller: _hScroll, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
                  child: DataTable(
                    headingRowHeight: 46, dataRowMinHeight: 40, dataRowMaxHeight: 54,
                    columnSpacing: 24, horizontalMargin: 16,
                    border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200), verticalInside: BorderSide(color: Colors.grey.shade100)),
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFE8F5E9)),
                    columns: rows.first.map((c) => DataColumn(label: Text(c?.value?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1B5E20))))).toList(),
                    rows: rows.skip(1).toList().asMap().entries.map((e) => DataRow(
                      color: WidgetStateProperty.resolveWith((s) => e.key.isEven ? Colors.white : const Color(0xFFF9FBF9)),
                      cells: e.value.map((c) => DataCell(Text(c?.value?.toString() ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.black87)))).toList(),
                    )).toList(),
                  ),
                ),
              )),
            )),
        ),
      ]);
    },
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PPTX — swipe navigation with PageView
// ══════════════════════════════════════════════════════════════════════════════
class _PptxBody extends StatefulWidget {
  const _PptxBody({required this.file});
  final PdfFileModel file;
  @override State<_PptxBody> createState() => _PptxBodyState();
}

class _PptxBodyState extends State<_PptxBody> {
  late final Future<List<List<String>>> _future = _parse();
  late final PageController _pageController = PageController();
  int _slide = 0;

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  Future<List<List<String>>> _parse() async {
    final bytes = await File(widget.file.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideFiles = archive.files
        .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml') && !f.name.contains('_rels'))
        .toList()
      ..sort((a, b) {
        int n(String s) => int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(s)?.group(1) ?? '0') ?? 0;
        return n(a.name).compareTo(n(b.name));
      });
    if (slideFiles.isEmpty) throw Exception('No slides found');
    return slideFiles.map((f) {
      final rawContent = f.content;
      final contentBytes = rawContent is List<int> ? rawContent : List<int>.from(rawContent as List);
      final xml = utf8.decode(contentBytes, allowMalformed: true);
      final lines = RegExp(r'<a:t[^>]*>(.*?)</a:t>', dotAll: true).allMatches(xml)
          .map((m) { final raw = m.group(1) ?? ''; return raw.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&apos;', "'").trim(); })
          .where((t) { if (t.isEmpty) return false; if (RegExp(r'[a-z]:[a-zA-Z]+=').hasMatch(t)) return false; return true; })
          .toList();
      return lines.isEmpty ? <String>['(empty slide)'] : lines;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<List<String>>>(
    future: _future,
    builder: (_, snap) {
      if (snap.connectionState != ConnectionState.done) return const _PageLoader();
      if (snap.hasError) return _PageError('${snap.error}');
      final slides = snap.data!;
      final total = slides.length;
      return Stack(children: [
        PageView.builder(
          controller: _pageController,
          itemCount: total,
          onPageChanged: (i) { HapticFeedback.selectionClick(); setState(() => _slide = i); },
          itemBuilder: (_, i) => _SlideCard(texts: slides[i], slideNumber: i + 1, totalSlides: total),
        ),
        Positioned(left: 24, right: 24, bottom: 24, child: _SlideNavPill(
          current: _slide, total: total,
          onPrev: _slide > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeInOut) : null,
          onNext: _slide < total - 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeInOut) : null,
        )),
      ]);
    },
  );
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.texts, required this.slideNumber, required this.totalSlides});
  final List<String> texts; final int slideNumber, totalSlides;
  @override
  Widget build(BuildContext context) {
    final title = texts.isNotEmpty ? texts.first : '';
    final body = texts.length > 1 ? texts.skip(1).toList() : <String>[];
    return Padding(padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 80.h),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(color: const Color(0xFF1A3A5C), padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Text('$slideNumber / $totalSlides', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10.sp, fontWeight: FontWeight.w600))),
            SizedBox(height: 10.h),
            SelectableText(title.isEmpty ? 'Slide $slideNumber' : title,
              style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700, height: 1.3)),
          ])),
          // Body
          Expanded(child: body.isEmpty
            ? Center(child: Text('(no content)', style: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp)))
            : Scrollbar(child: SingleChildScrollView(physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body.map((line) {
                  final isBullet = line.startsWith('•') || line.startsWith('-') || line.startsWith('*');
                  return Padding(padding: const EdgeInsets.only(bottom: 10), child: isBullet
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 7, right: 10),
                          decoration: const BoxDecoration(color: Color(0xFF2E6DA4), shape: BoxShape.circle)),
                        Expanded(child: SelectableText(line.replaceFirst(RegExp(r'^[•\-\*]\s*'), ''),
                          style: TextStyle(fontSize: 14.sp, color: Colors.black87, height: 1.6))),
                      ])
                    : SelectableText(line, style: TextStyle(fontSize: 14.sp, color: Colors.black87, height: 1.6)));
                }).toList())))),
        ]),
      ));
  }
}

class _SlideNavPill extends StatelessWidget {
  const _SlideNavPill({required this.current, required this.total, required this.onPrev, required this.onNext});
  final int current, total;
  final VoidCallback? onPrev, onNext;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(40),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))]),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _NavBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onPrev),
      if (total <= 7)
        Row(children: List.generate(total, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == current ? 20 : 6, height: 6,
          decoration: BoxDecoration(color: i == current ? Colors.white : Colors.white.withOpacity(0.35), borderRadius: BorderRadius.circular(3)),
        )))
      else
        Text('${current + 1} / $total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      _NavBtn(icon: Icons.arrow_forward_ios_rounded, onTap: onNext),
    ]),
  );
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, this.onTap});
  final IconData icon; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(
    onTap: onTap != null ? () { HapticFeedback.selectionClick(); onTap!(); } : null,
    borderRadius: BorderRadius.circular(24),
    child: Padding(padding: const EdgeInsets.all(10), child: AnimatedOpacity(
      opacity: onTap != null ? 1.0 : 0.3, duration: const Duration(milliseconds: 150),
      child: Icon(icon, color: Colors.white, size: 18),
    )),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
// IMAGE — full-screen pinch-zoom
// ══════════════════════════════════════════════════════════════════════════════
class _ImageBody extends StatefulWidget {
  const _ImageBody({required this.file});
  final PdfFileModel file;
  @override State<_ImageBody> createState() => _ImageBodyState();
}

class _ImageBodyState extends State<_ImageBody> {
  final _transformController = TransformationController();
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _showInfo = false); });
  }

  @override
  void dispose() { _transformController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _showInfo = !_showInfo),
    onDoubleTap: () { HapticFeedback.mediumImpact(); _transformController.value = Matrix4.identity(); },
    child: Stack(fit: StackFit.expand, children: [
      InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5, maxScale: 10.0,
        child: Center(child: Image.file(File(widget.file.path), fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _PageError('Cannot display image'))),
      ),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut,
        bottom: _showInfo ? 24 : -80, left: 24, right: 24,
        child: IgnorePointer(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Pinch to zoom · Double-tap to reset', style: TextStyle(color: Colors.white70, fontSize: 12.sp))),
          ]),
        )),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// UNKNOWN
// ══════════════════════════════════════════════════════════════════════════════
class _UnknownBody extends StatelessWidget {
  const _UnknownBody({required this.file});
  final PdfFileModel file;
  @override
  Widget build(BuildContext context) => Center(child: _PageCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72,
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(file.extension.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF455A64))))),
    const SizedBox(height: 16),
    Text('Cannot preview this file', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    Text('.${file.extension.toLowerCase()} files cannot be previewed.\nUse Share to open in another app.',
      style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.6), textAlign: TextAlign.center),
    const SizedBox(height: 20),
    OutlinedButton.icon(
      onPressed: () => Share.shareXFiles([XFile(file.path)], subject: file.name),
      icon: const Icon(Icons.share_rounded, size: 16), label: const Text('Share File'),
      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A3A5C), side: const BorderSide(color: Color(0xFF1A3A5C)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
  ])));
}