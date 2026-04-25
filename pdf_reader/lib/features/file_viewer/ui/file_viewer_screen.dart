import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../shared/models/pdf_file_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FileViewerScreen — opens ANY supported file inline, no external app needed.
//
//  PDF          → SfPdfViewer
//  TXT / CSV    → scrollable plain text
//  XLSX         → sheet tabs + scrollable data table
//  DOCX         → extracted paragraphs rendered as rich text
//  PPTX         → slide-by-slide card viewer
//  Image        → zoomable Image.file
// ─────────────────────────────────────────────────────────────────────────────
class FileViewerScreen extends StatelessWidget {
  const FileViewerScreen({super.key, required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(file.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (file.fileType) {
      case FileType.pdf:
        return _PdfView(file: file);
      case FileType.txt:
      case FileType.csv:
        return _PlainTextView(file: file);
      case FileType.xlsx:
        return _ExcelView(file: file);
      case FileType.docx:
        return _DocxView(file: file);
      case FileType.pptx:
        return _PptxView(file: file);
      case FileType.image:
        return _ImageView(file: file);
      case FileType.unknown:
        return _UnknownView(file: file);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF
// ─────────────────────────────────────────────────────────────────────────────
class _PdfView extends StatelessWidget {
  const _PdfView({required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) => SfPdfViewer.file(
        file.file,
        enableDoubleTapZooming: true,
        interactionMode: PdfInteractionMode.pan,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TXT / CSV
// ─────────────────────────────────────────────────────────────────────────────
class _PlainTextView extends StatefulWidget {
  const _PlainTextView({required this.file});
  final PdfFileModel file;

  @override
  State<_PlainTextView> createState() => _PlainTextViewState();
}

class _PlainTextViewState extends State<_PlainTextView> {
  late final Future<String> _future =
      File(widget.file.path).readAsString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _Loader();
        }
        if (snap.hasError) return _ErrorView('${snap.error}');
        return Scrollbar(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: SelectableText(
              snap.data ?? '',
              style: TextStyle(fontFamily: 'monospace', fontSize: 13.sp),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XLSX
// ─────────────────────────────────────────────────────────────────────────────
class _ExcelView extends StatefulWidget {
  const _ExcelView({required this.file});
  final PdfFileModel file;

  @override
  State<_ExcelView> createState() => _ExcelViewState();
}

class _ExcelViewState extends State<_ExcelView> {
  late final Future<excel_pkg.Excel> _future = _load();
  int _sheetIndex = 0;

  Future<excel_pkg.Excel> _load() async {
    final bytes = await File(widget.file.path).readAsBytes();
    return excel_pkg.Excel.decodeBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<excel_pkg.Excel>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const _Loader();
        if (snap.hasError || snap.data == null) {
          return _ErrorView('Cannot read Excel: ${snap.error}');
        }

        final excel  = snap.data!;
        final sheets = excel.tables.keys.toList();
        if (sheets.isEmpty) return const _ErrorView('No sheets found');
        if (_sheetIndex >= sheets.length) _sheetIndex = 0;

        final rows = excel.tables[sheets[_sheetIndex]]!.rows;

        return Column(
          children: [
            // ── Sheet tabs ──────────────────────────────────────────────────
            if (sheets.length > 1)
              SizedBox(
                height: 44.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  itemCount: sheets.length,
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ChoiceChip(
                      label: Text(sheets[i]),
                      selected: i == _sheetIndex,
                      onSelected: (_) => setState(() => _sheetIndex = i),
                    ),
                  ),
                ),
              ),

            // ── Table ───────────────────────────────────────────────────────
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Sheet is empty'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(cs.primaryContainer),
                          border: TableBorder.all(
                              color: theme.dividerColor, width: 0.5),
                          columns: rows.first
                              .map((c) => DataColumn(
                                    label: Text(
                                      c?.value?.toString() ?? '',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.sp),
                                    ),
                                  ))
                              .toList(),
                          rows: rows.skip(1).map((row) {
                            return DataRow(
                              cells: row
                                  .map((c) => DataCell(Text(
                                        c?.value?.toString() ?? '',
                                        style: TextStyle(fontSize: 12.sp),
                                      )))
                                  .toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCX  — extracts paragraphs from word/document.xml (same logic as
//          ConversionService._fromDocx, but renders instead of converting)
// ─────────────────────────────────────────────────────────────────────────────
class _DocxView extends StatefulWidget {
  const _DocxView({required this.file});
  final PdfFileModel file;

  @override
  State<_DocxView> createState() => _DocxViewState();
}

class _DocxViewState extends State<_DocxView> {
  late final Future<List<_DocxPara>> _future = _parse();

  Future<List<_DocxPara>> _parse() async {
    final bytes = await File(widget.file.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('Not a valid DOCX file'),
    );

    final xml = utf8.decode(docFile.content as List<int>, allowMalformed: true);
    final paras = <_DocxPara>[];

    for (final m
        in RegExp(r'<w:p[ >].*?</w:p>', dotAll: true).allMatches(xml)) {
      final paraXml = m.group(0)!;

      final styleVal = RegExp(r'<w:pStyle[^>]+w:val="([^"]+)"')
              .firstMatch(paraXml)
              ?.group(1)
              ?.toLowerCase() ??
          '';

      final runs = RegExp(r'<w:r[ >].*?</w:r>', dotAll: true)
          .allMatches(paraXml)
          .map((r) => r.group(0)!)
          .toList();

      final isBold = runs.isNotEmpty &&
          runs.every((r) => r.contains('<w:b/>') || r.contains('<w:b '));

      final text = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
          .allMatches(paraXml)
          .map((t) => t.group(1) ?? '')
          .join('');

      if (text.trim().isEmpty) continue;

      _DocxStyle style = _DocxStyle.body;
      if (styleVal.contains('heading1') ||
          styleVal == 'title' ||
          styleVal == 'heading 1') {
        style = _DocxStyle.h1;
      } else if (styleVal.contains('heading2') ||
          styleVal == 'subtitle' ||
          styleVal == 'heading 2') {
        style = _DocxStyle.h2;
      } else if (styleVal.contains('heading3') || styleVal == 'heading 3') {
        style = _DocxStyle.h3;
      } else if (isBold && text.trim().length <= 80) {
        style = _DocxStyle.h2;
      }

      paras.add(_DocxPara(text: text, style: style));
    }

    if (paras.isEmpty) throw Exception('No text found in this DOCX file');
    return paras;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<_DocxPara>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const _Loader();
        if (snap.hasError) return _ErrorView('${snap.error}');

        final paras = snap.data!;
        return Scrollbar(
          child: ListView.builder(
            padding: EdgeInsets.all(20.w),
            itemCount: paras.length,
            itemBuilder: (_, i) {
              final p = paras[i];
              TextStyle style;
              switch (p.style) {
                case _DocxStyle.h1:
                  style = theme.textTheme.headlineSmall!
                      .copyWith(fontWeight: FontWeight.w800);
                  break;
                case _DocxStyle.h2:
                  style = theme.textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.w700);
                  break;
                case _DocxStyle.h3:
                  style = theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.w600);
                  break;
                case _DocxStyle.body:
                  style = theme.textTheme.bodyMedium!;
                  break;
              }
              return Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: SelectableText(p.text, style: style),
              );
            },
          ),
        );
      },
    );
  }
}

enum _DocxStyle { h1, h2, h3, body }

class _DocxPara {
  const _DocxPara({required this.text, required this.style});
  final String text;
  final _DocxStyle style;
}

// ─────────────────────────────────────────────────────────────────────────────
// PPTX  — extracts slide text from ppt/slides/slideN.xml (same logic as
//          ConversionService._fromPptx, but renders slides as cards)
// ─────────────────────────────────────────────────────────────────────────────
class _PptxView extends StatefulWidget {
  const _PptxView({required this.file});
  final PdfFileModel file;

  @override
  State<_PptxView> createState() => _PptxViewState();
}

class _PptxViewState extends State<_PptxView> {
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
        int num(String n) =>
            int.tryParse(RegExp(r'slide(\d+)\.xml').firstMatch(n)?.group(1) ?? '0') ?? 0;
        return num(a.name).compareTo(num(b.name));
      });

    if (slideFiles.isEmpty) throw Exception('No slides found in this PPTX file');

    return slideFiles.map((f) {
      final xml = utf8.decode(f.content as List<int>, allowMalformed: true);
      final lines = RegExp(r'<a:t[^>]*>(.*?)<\/a:t>', dotAll: true)
          .allMatches(xml)
          .map((m) => m.group(1)?.trim() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      return lines.isEmpty ? <String>['(empty slide)'] : lines;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return FutureBuilder<List<List<String>>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const _Loader();
        if (snap.hasError) return _ErrorView('${snap.error}');

        final slides = snap.data!;
        final total  = slides.length;
        final texts  = slides[_slide];

        return Column(
          children: [
            // ── Slide card ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r)),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.w),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Slide number badge
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'Slide ${_slide + 1} of $total',
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onPrimaryContainer),
                            ),
                          ),
                          SizedBox(height: 20.h),

                          // First line = title
                          if (texts.isNotEmpty)
                            SelectableText(
                              texts.first,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),

                          // Rest = body
                          if (texts.length > 1) ...[
                            SizedBox(height: 16.h),
                            ...texts.skip(1).map((line) => Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: SelectableText(
                                    line,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Navigation ──────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _slide > 0
                          ? () => setState(() => _slide--)
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Prev'),
                    ),
                    Text(
                      '${_slide + 1} / $total',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    ElevatedButton.icon(
                      onPressed: _slide < total - 1
                          ? () => setState(() => _slide++)
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Next'),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Image
// ─────────────────────────────────────────────────────────────────────────────
class _ImageView extends StatelessWidget {
  const _ImageView({required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(file.path),
            errorBuilder: (_, __, ___) =>
                const _ErrorView('Cannot display image'),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Unknown
// ─────────────────────────────────────────────────────────────────────────────
class _UnknownView extends StatelessWidget {
  const _UnknownView({required this.file});
  final PdfFileModel file;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                size: 64.sp,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
            SizedBox(height: 16.h),
            Text(
              'Cannot preview .${file.extension.toLowerCase()} files',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            message,
            style:
                TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
        ),
      );
}