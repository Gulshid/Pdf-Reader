// ignore_for_file: avoid_print

import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
// ignore: unused_import
import 'dart:ui' show Rect;
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../shared/models/conversion_task_model.dart';
import 'file_utils.dart';

typedef ProgressCallback = void Function(double progress);

class ConversionService {
  ConversionService();

  Future<String> convert({
    required ConversionTaskModel task,
    required ProgressCallback onProgress,
  }) async {
    print('\n═══════════════════════════════════════════════════════');
    print('🟢 CONVERSION STARTED');
    print('   Source: ${task.sourceFilePath}');
    print('   Format: ${task.sourceFormat} → ${task.targetFormat}');
    print('═══════════════════════════════════════════════════════\n');

    try {
      final sourceFile = File(task.sourceFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist: ${task.sourceFilePath}');
      }
      final sourceSize = await sourceFile.length();
      print('📄 Source file exists - Size: $sourceSize bytes');

      if (sourceSize == 0) {
        throw Exception('Source file is empty (0 bytes)');
      }

      final outputPath = await FileUtils.buildOutputPath(
        task.sourceFilePath,
        task.targetFormat,
      );
      print('📂 Target output path: $outputPath');

      final outDir = Directory(p.dirname(outputPath));
      if (!await outDir.exists()) {
        print('📁 Creating output directory: ${outDir.path}');
        await outDir.create(recursive: true);
      }

      onProgress(0.1);
      print('📍 Progress: 10%');

      String actualOutputPath = outputPath;

      switch (task.sourceFormat) {
        case SupportedFormat.pdf:
          print('🔄 Converting PDF → ${task.targetFormat}');
          actualOutputPath = await _fromPdf(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
        case SupportedFormat.txt:
          print('🔄 Converting TXT → ${task.targetFormat}');
          await _fromTxt(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
        case SupportedFormat.jpg:
        case SupportedFormat.png:
          print('🔄 Converting Image → ${task.targetFormat}');
          await _fromImage(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
        case SupportedFormat.csv:
          print('🔄 Converting CSV → ${task.targetFormat}');
          await _fromCsv(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
        case SupportedFormat.xlsx:
          print('🔄 Converting XLSX → ${task.targetFormat}');
          await _fromXlsx(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
        case SupportedFormat.docx:
          print('🔄 Converting DOCX → ${task.targetFormat}');
          await _fromDocx(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
        case SupportedFormat.pptx:
          print('🔄 Converting PPTX → ${task.targetFormat}');
          await _fromPptx(
              task.sourceFilePath, task.targetFormat, outputPath, onProgress);
          break;
      }

      onProgress(1.0);
      print('📍 Progress: 100%');

      final outFile = File(actualOutputPath);
      if (!await outFile.exists()) {
        throw Exception('Output file was not created at: $actualOutputPath');
      }

      final outSize = await outFile.length();
      if (outSize == 0) {
        throw Exception(
            'Output file is empty (0 bytes) at: $actualOutputPath');
      }

      print('\n✅ CONVERSION SUCCESSFUL!');
      print('   File: $actualOutputPath');
      print('   Size: $outSize bytes');
      print('═══════════════════════════════════════════════════════\n');

      return actualOutputPath;
    } catch (e, stackTrace) {
      print('\n❌ CONVERSION FAILED!');
      print('   Error: $e');
      print('   StackTrace: $stackTrace');
      print('═══════════════════════════════════════════════════════\n');
      rethrow;
    }
  }

  Future<pw.Font> _loadFont() async {
    // ── Tier 1: system fonts (fast path on most Android devices) ──────────
    const List<String> systemPaths = [
      '/system/fonts/Roboto-Regular.ttf',
      '/system/fonts/NotoSans-Regular.ttf',
      '/system/fonts/DroidSans.ttf',
      '/system/fonts/DroidSansFallback.ttf',
      '/system/fonts/NotoNaskhArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic-Regular.ttf',
    ];
    for (final path in systemPaths) {
      try {
        final f = File(path);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            print('✅ _loadFont: system → $path');
            return pw.Font.ttf(bytes.buffer.asByteData());
          }
        }
      } catch (_) {}
    }

    // ── Tier 2: bundled asset ──────────────────────────────────────────────
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      print('✅ _loadFont: asset bundle');
      return pw.Font.ttf(data);
    } catch (e) {
      print('❌ _loadFont: asset failed → $e');
    }

    // ── Tier 3: copy asset to temp file and load from disk ─────────────────
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final tempDir = await getTemporaryDirectory();
      final tempFont = File(p.join(tempDir.path, 'NotoSans-Regular.ttf'));
      await tempFont.writeAsBytes(data.buffer.asUint8List());
      final bytes = await tempFont.readAsBytes();
      print('✅ _loadFont: asset→tempfile');
      return pw.Font.ttf(bytes.buffer.asByteData());
    } catch (e) {
      print('❌ _loadFont: tempfile fallback failed → $e');
    }

    // ── Tier 4: absolute last resort ──────────────────────────────────────
    print('⚠️ _loadFont: all tiers failed, using courier');
    return pw.Font.courier();
  }

  // ── PDF → * ───────────────────────────────────────────────────────────────

  Future<String> _fromPdf(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    switch (target) {
      case SupportedFormat.txt:
        final text = await _extractTextFromPdf(src, onProgress);
        await File(output).writeAsString(text, encoding: utf8);
        return output;

      case SupportedFormat.jpg:
      case SupportedFormat.png:
        final imgFmt = target == SupportedFormat.jpg
            ? pdfx.PdfPageImageFormat.jpeg
            : pdfx.PdfPageImageFormat.png;
        final imgExt = target == SupportedFormat.jpg ? 'jpg' : 'png';
        final pdfDoc = await pdfx.PdfDocument.openFile(src);
        onProgress(0.2);
        try {
          final totalPages = pdfDoc.pagesCount;
          if (totalPages == 1) {
            final page = await pdfDoc.getPage(1);
            final pageImage = await page.render(
              width: page.width * 3,
              height: page.height * 3,
              format: imgFmt,
              backgroundColor: '#FFFFFF',
            );
            await page.close();
            onProgress(0.9);
            if (pageImage == null) throw Exception('Failed to render PDF page.');
            if (pageImage.bytes.isEmpty) {
              throw Exception('Rendered page produced empty bytes.');
            }
            await File(output).writeAsBytes(pageImage.bytes);
            return output;
          } else {
            final zipOutput = output.replaceAll(
                RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '.zip');
            final archive = Archive();
            for (int pg = 1; pg <= totalPages; pg++) {
              final page = await pdfDoc.getPage(pg);
              final pageImage = await page.render(
                width: page.width * 3,
                height: page.height * 3,
                format: imgFmt,
                backgroundColor: '#FFFFFF',
              );
              await page.close();
              if (pageImage == null || pageImage.bytes.isEmpty) continue;
              final name = 'page_${pg.toString().padLeft(3, "0")}.$imgExt';
              archive.addFile(
                  ArchiveFile(name, pageImage.bytes.length, pageImage.bytes));
              onProgress(0.2 + 0.7 * pg / totalPages);
            }
            final zipBytes = ZipEncoder().encode(archive);
            if (zipBytes == null || zipBytes.isEmpty) {
              throw Exception('ZIP encoding failed');
            }
            await File(zipOutput).writeAsBytes(zipBytes);
            return zipOutput;
          }
        } finally {
          await pdfDoc.close();
        }

      case SupportedFormat.docx:
        final text = await _extractTextFromPdf(src, onProgress);
        await _writeDocx(text, output, onProgress);
        return output;

      case SupportedFormat.xlsx:
        final text = await _extractTextFromPdf(src, onProgress);
        await _writeXlsx(text, output);
        return output;

      case SupportedFormat.csv:
        final text = await _extractTextFromPdf(src, onProgress);
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
        final csv = lines.map((l) => _escapeCsv(l.trim())).join('\n');
        await File(output).writeAsString(csv, encoding: utf8);
        return output;

      case SupportedFormat.pptx:
        final text = await _extractTextFromPdf(src, onProgress);
        await _writePptx(text, output, onProgress);
        return output;

      default:
        throw UnsupportedError('PDF -> ${target.label} not supported');
    }
  }

  Future<String> _extractTextFromPdf(
    String src,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    onProgress(0.2);

    final buffer = StringBuffer();
    final extractor = sf.PdfTextExtractor(sfDoc);
    final pageCount = sfDoc.pages.count;

    for (int i = 0; i < pageCount; i++) {
      final pageText = extractor.extractText(
        startPageIndex: i,
        endPageIndex: i,
      );
      if (pageText.trim().isNotEmpty) {
        final rawLines = pageText.split('\n');
        final rejoined = StringBuffer();
        for (int j = 0; j < rawLines.length; j++) {
          final line = rawLines[j].trimRight();
          if (line.isEmpty) {
            rejoined.write('\n\n');
            continue;
          }
          if (line.endsWith('-')) {
            rejoined.write(line.substring(0, line.length - 1));
            continue;
          }
          final nextLine = rawLines.skip(j + 1).firstWhere(
                (l) => l.trim().isNotEmpty,
                orElse: () => '',
              );
          final nextStartsLower = nextLine.isNotEmpty &&
              nextLine.trimLeft()[0] == nextLine.trimLeft()[0].toLowerCase() &&
              nextLine.trimLeft()[0] != nextLine.trimLeft()[0].toUpperCase();
          if (nextStartsLower) {
            rejoined.write('$line ');
          } else {
            rejoined.write('$line\n');
          }
        }
        buffer.write(rejoined.toString().trim());
        buffer.write('\n\n');
      }
      onProgress(0.2 + 0.3 * (i + 1) / pageCount);
    }

    sfDoc.dispose();

    final directText = buffer.toString().trim();
    if (directText.isNotEmpty) return directText;

    // OCR fallback for scanned/image-only PDFs
    final ocrBuffer = StringBuffer();
    final pdfxDoc = await pdfx.PdfDocument.openFile(src);
    final tempDir = await getTemporaryDirectory();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      for (int i = 1; i <= pdfxDoc.pagesCount; i++) {
        final page = await pdfxDoc.getPage(i);
        final rendered = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (rendered == null || rendered.bytes.isEmpty) continue;

        final tmpFile = File(p.join(tempDir.path, 'ocr_page_$i.png'));
        await tmpFile.writeAsBytes(rendered.bytes);
        final inputImage = InputImage.fromFile(tmpFile);
        final recognizedText = await recognizer.processImage(inputImage);
        if (recognizedText.text.trim().isNotEmpty) {
          ocrBuffer.writeln(recognizedText.text);
        }
        await tmpFile.delete();
        onProgress(0.5 + 0.45 * i / pdfxDoc.pagesCount);
      }
    } finally {
      await pdfxDoc.close();
      recognizer.close();
    }

    final ocrText = ocrBuffer.toString().trim();
    return ocrText.isNotEmpty
        ? ocrText
        : 'No text could be extracted from this PDF (fully image-based with no readable text).';
  }

  // ── TXT → * ───────────────────────────────────────────────────────────────

  Future<void> _fromTxt(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    final text = _decodeText(bytes);
    onProgress(0.3);

    switch (target) {
      case SupportedFormat.pdf:
        await _textToPdf(text, output, onProgress);
        break;
      case SupportedFormat.docx:
        await _writeDocx(text, output, onProgress);
        break;
      case SupportedFormat.xlsx:
        onProgress(0.5);
        await _writeXlsx(text, output);
        break;
      case SupportedFormat.pptx:
        await _writePptx(text, output, onProgress);
        break;
      default:
        throw UnsupportedError('TXT -> ${target.label} not supported');
    }
  }

  // ── Image → * ─────────────────────────────────────────────────────────────

  Future<void> _fromImage(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    onProgress(0.3);

    switch (target) {
      case SupportedFormat.pdf:
        final decoded = img.decodeImage(bytes);
        if (decoded == null) throw Exception('Cannot decode image: $src');
        final pngBytes = Uint8List.fromList(img.encodePng(decoded));

        final pdfDoc = pw.Document();
        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(pngBytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ));
        onProgress(0.7);
        final pdfBytes = await pdfDoc.save();
        if (pdfBytes.isEmpty) throw Exception('PDF generation failed');
        await File(output).writeAsBytes(pdfBytes);
        break;

      case SupportedFormat.jpg:
        if (src.toLowerCase().endsWith('.jpg') ||
            src.toLowerCase().endsWith('.jpeg')) {
          await File(output).writeAsBytes(bytes);
        } else {
          final d = img.decodeImage(bytes);
          if (d == null) throw Exception('Cannot decode image');
          await File(output).writeAsBytes(
              Uint8List.fromList(img.encodeJpg(d, quality: 92)));
        }
        break;

      case SupportedFormat.png:
        if (src.toLowerCase().endsWith('.png')) {
          await File(output).writeAsBytes(bytes);
        } else {
          final d = img.decodeImage(bytes);
          if (d == null) throw Exception('Cannot decode image');
          await File(output)
              .writeAsBytes(Uint8List.fromList(img.encodePng(d)));
        }
        break;

      default:
        throw UnsupportedError('Image -> ${target.label} not supported');
    }
  }

  // ── CSV → * ───────────────────────────────────────────────────────────────

  Future<void> _fromCsv(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final content = _decodeText(await File(src).readAsBytes());
    onProgress(0.3);
    final rows = _parseCsvRows(content);
    final data = rows.isEmpty ? [['(empty)']] : rows;

    switch (target) {
      case SupportedFormat.pdf:
        final pdfDoc = pw.Document();
        const csvRowsPerPage = 30;
        final csvTotalRows = data.length;
        int csvStart = 0;
        while (csvStart < csvTotalRows) {
          final csvEnd = (csvStart + csvRowsPerPage < csvTotalRows)
              ? csvStart + csvRowsPerPage
              : csvTotalRows;
          final pageData = data.sublist(csvStart, csvEnd);
          pdfDoc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (ctx) => pw.TableHelper.fromTextArray(
              data: pageData,
              border: pw.TableBorder.all(width: 0.5),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ));
          csvStart = csvEnd;
        }
        onProgress(0.7);
        final csvPdfBytes = await pdfDoc.save();
        if (csvPdfBytes.isEmpty) throw Exception('CSV→PDF generation failed');
        await File(output).writeAsBytes(csvPdfBytes);
        break;

      case SupportedFormat.xlsx:
        onProgress(0.5);
        final ex = excel_pkg.Excel.createExcel();
        final sheet = ex['Sheet1'];
        for (final row in data) {
          sheet.appendRow(
              row.map((c) => excel_pkg.TextCellValue(c.trim())).toList());
        }
        final b = ex.save();
        if (b == null) throw Exception('XLSX encode failed');
        await File(output).writeAsBytes(b);
        break;

      case SupportedFormat.txt:
        final lines = data.map((r) => r.join('\t')).join('\n');
        await File(output).writeAsString(lines, encoding: utf8);
        break;

      case SupportedFormat.docx:
        final docxText = data.map((r) => r.join('\t')).join('\n');
        await _writeDocx(docxText, output, onProgress);
        break;

      case SupportedFormat.pptx:
        final pptxText = data.map((r) => r.join('\t')).join('\n');
        await _writePptx(pptxText, output, onProgress);
        break;

      default:
        throw UnsupportedError('CSV -> ${target.label} not supported');
    }
  }

  // ── XLSX → * ──────────────────────────────────────────────────────────────

  Future<void> _fromXlsx(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    print('   📊 Reading XLSX file: $src');

    final bytes = await File(src).readAsBytes();
    print('   📊 XLSX size: ${bytes.length} bytes');

    onProgress(0.3);

    final ex = excel_pkg.Excel.decodeBytes(bytes);
    if (ex.tables.isEmpty) {
      throw Exception('XLSX has no sheets');
    }

    print('   📊 Sheets found: ${ex.tables.keys.join(', ')}');

    final sheet = ex.tables[ex.tables.keys.first]!;
    onProgress(0.5);

    final rows = <List<String>>[];
    for (final row in sheet.rows) {
      final cells = row.map((c) {
        if (c == null) return '';
        final v = c.value;
        if (v == null) return '';
        if (v is excel_pkg.TextCellValue) return v.value.toString();
        if (v is excel_pkg.IntCellValue) return v.value.toString();
        if (v is excel_pkg.DoubleCellValue) return v.value.toString();
        if (v is excel_pkg.BoolCellValue) return v.value.toString();
        if (v is excel_pkg.DateCellValue) {
          try {
            return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
          } catch (_) {
            return v.toString();
          }
        }
        if (v is excel_pkg.DateTimeCellValue) {
          try {
            return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
                '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
          } catch (_) {
            return v.toString();
          }
        }
        if (v is excel_pkg.TimeCellValue) {
          try {
            return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}:${v.second.toString().padLeft(2, '0')}';
          } catch (_) {
            return v.toString();
          }
        }
        if (v is excel_pkg.FormulaCellValue) {
          return v
              .toString()
              .replaceAll('FormulaCellValue(', '')
              .replaceAll(')', '');
        }
        return v.toString();
      }).toList();

      if (cells.any((c) => c.trim().isNotEmpty)) {
        rows.add(cells);
      }
    }

    print('   📊 Rows extracted: ${rows.length}');
    if (rows.isNotEmpty) {
      print('   📊 First row:  ${rows.first.take(5).join(' | ')}');
    }

    if (rows.isEmpty) {
      _assertTextNotEmpty('', 'XLSX');
    }

    final data = rows.isEmpty ? [['(empty)']] : rows;

    switch (target) {
      case SupportedFormat.pdf:
        print('   📄 Generating PDF from XLSX data...');
        final pdfDoc = pw.Document();
        const rowsPerPage = 30;
        final totalRows = data.length;
        int startRow = 0;

        while (startRow < totalRows) {
          final endRow = (startRow + rowsPerPage < totalRows)
              ? startRow + rowsPerPage
              : totalRows;
          final pageData = data.sublist(startRow, endRow);
          final capturedStart = startRow;
          pdfDoc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Page ${(capturedStart ~/ rowsPerPage) + 1} of ${(totalRows / rowsPerPage).ceil()}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  data: pageData,
                  border: pw.TableBorder.all(width: 0.5),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headerStyle: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold),
                  cellPadding: const pw.EdgeInsets.all(4),
                  columnWidths: {0: const pw.FlexColumnWidth()},
                ),
              ],
            ),
          ));
          startRow = endRow;
        }
        onProgress(0.8);
        final pdfBytes = await pdfDoc.save();
        print('   📄 PDF generated: ${pdfBytes.length} bytes');
        await File(output).writeAsBytes(pdfBytes);
        break;

      case SupportedFormat.csv:
        final csv = data.map((r) => r.map(_escapeCsv).join(',')).join('\n');
        await File(output).writeAsString(csv, encoding: utf8);
        break;

      case SupportedFormat.txt:
        final txt = data.map((r) => r.join('\t')).join('\n');
        await File(output).writeAsString(txt, encoding: utf8);
        break;

      case SupportedFormat.docx:
        final docxText = data.map((r) => r.join('\t')).join('\n');
        await _writeDocx(docxText, output, onProgress);
        break;

      case SupportedFormat.pptx:
        final pptxText = data.map((r) => r.join('\t')).join('\n');
        await _writePptx(pptxText, output, onProgress);
        break;

      default:
        throw UnsupportedError('XLSX -> ${target.label} not supported');
    }
  }

  // ── DOCX → * ──────────────────────────────────────────────────────────────

  Future<void> _fromDocx(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    onProgress(0.2);

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('Cannot read DOCX (not a valid zip): $e');
    }

    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('word/document.xml not found in DOCX'),
    );

    final xml = utf8.decode(docFile.content, allowMalformed: true);

    final buf = StringBuffer();
    bool lastWasParagraph = false;
    for (final m
        in RegExp(r'<w:p[ >].*?</w:p>', dotAll: true).allMatches(xml)) {
      final paraXml = m.group(0)!;

      final styleMatch = RegExp(r'<w:pStyle[^>]+w:val="([^"]+)"')
          .firstMatch(paraXml);
      final styleVal = styleMatch?.group(1)?.toLowerCase() ?? '';

      final runXmls = RegExp(r'<w:r[ >].*?</w:r>', dotAll: true)
          .allMatches(paraXml)
          .map((r) => r.group(0)!)
          .toList();
      final hasBold = runXmls.isNotEmpty &&
          runXmls.every((r) => r.contains('<w:b/>') || r.contains('<w:b '));

      final texts = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
          .allMatches(paraXml)
          .map((t) => t.group(1) ?? '')
          .join('');

      if (texts.trim().isNotEmpty) {
        if (styleVal.contains('heading 1') ||
            styleVal.contains('heading1') ||
            styleVal == 'title') {
          buf.writeln('# ${texts.trim()}');
        } else if (styleVal.contains('heading 2') ||
            styleVal.contains('heading2') ||
            styleVal == 'subtitle') {
          buf.writeln('## ${texts.trim()}');
        } else if (styleVal.contains('heading 3') ||
            styleVal.contains('heading3')) {
          buf.writeln('### ${texts.trim()}');
        } else if (hasBold && texts.trim().length <= 80) {
          buf.writeln('## ${texts.trim()}');
        } else {
          buf.writeln(texts);
        }
        lastWasParagraph = false;
      } else if (!lastWasParagraph) {
        buf.writeln();
        lastWasParagraph = true;
      }
    }

    onProgress(0.5);
    final text = buf.toString().trim();
    print('   📝 DOCX extracted ${text.length} characters');
    _assertTextNotEmpty(text, 'DOCX');

    switch (target) {
      case SupportedFormat.pdf:
        await _textToPdf(text, output, onProgress);
        break;
      case SupportedFormat.txt:
        await File(output).writeAsString(text, encoding: utf8);
        break;
      case SupportedFormat.xlsx:
        await _writeXlsx(text, output);
        break;
      case SupportedFormat.pptx:
        await _writePptx(text, output, onProgress);
        break;
      case SupportedFormat.csv:
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
        final csv = lines.map((l) => _escapeCsv(l.trim())).join('\n');
        await File(output).writeAsString(csv, encoding: utf8);
        break;
      default:
        throw UnsupportedError('DOCX -> ${target.label} not supported');
    }
  }

  // ── PPTX → * ──────────────────────────────────────────────────────────────

  Future<void> _fromPptx(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    onProgress(0.2);
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('Cannot read PPTX: $e');
    }

    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') &&
            f.name.endsWith('.xml') &&
            !f.name.contains('_rels'))
        .toList()
      ..sort((a, b) {
        final numA = int.tryParse(
                RegExp(r'slide(\d+)\.xml').firstMatch(a.name)?.group(1) ?? '0') ??
            0;
        final numB = int.tryParse(
                RegExp(r'slide(\d+)\.xml').firstMatch(b.name)?.group(1) ?? '0') ??
            0;
        return numA.compareTo(numB);
      });

    final slideTexts = <List<String>>[];
    for (final slide in slideFiles) {
      final xml = utf8.decode(slide.content, allowMalformed: true);
      final lines = RegExp(r'<a:t[^>]*>(.*?)<\/a:t>', dotAll: true)
          .allMatches(xml)
          .map((m) => m.group(1)?.trim() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      slideTexts.add(lines.isEmpty ? ['(no text)'] : lines);
    }

    onProgress(0.4);

    switch (target) {
      case SupportedFormat.pdf:
        await _pptxToPdf(slideTexts, output, onProgress);
        break;
      case SupportedFormat.txt:
        final buf = StringBuffer();
        for (int i = 0; i < slideTexts.length; i++) {
          buf.writeln('--- Slide ${i + 1} ---');
          for (final l in slideTexts[i]) {
            buf.writeln(l);
          }
          buf.writeln();
        }
        await File(output).writeAsString(buf.toString(), encoding: utf8);
        break;
      case SupportedFormat.docx:
        final buf = StringBuffer();
        for (int i = 0; i < slideTexts.length; i++) {
          buf.writeln('--- Slide ${i + 1} ---');
          for (final l in slideTexts[i]) {
            buf.writeln(l);
          }
          buf.writeln();
        }
        await _writeDocx(buf.toString(), output, onProgress);
        break;
      case SupportedFormat.xlsx:
        final buf = StringBuffer();
        for (int i = 0; i < slideTexts.length; i++) {
          buf.writeln('--- Slide ${i + 1} ---');
          for (final l in slideTexts[i]) {
            buf.writeln(l);
          }
          buf.writeln();
        }
        await _writeXlsx(buf.toString(), output);
        break;
      case SupportedFormat.csv:
        final buf = StringBuffer();
        for (int i = 0; i < slideTexts.length; i++) {
          for (final l in slideTexts[i]) {
            buf.writeln('${_escapeCsv('Slide ${i + 1}')},${_escapeCsv(l)}');
          }
        }
        await File(output).writeAsString(buf.toString(), encoding: utf8);
        break;
      default:
        throw UnsupportedError('PPTX -> ${target.label} not supported');
    }
    // ← _fromPptx ends here (was missing in original, causing all methods below
    //   to be accidentally nested inside _fromPptx)
  }

  // ── PPTX → PDF ────────────────────────────────────────────────────────────

  Future<void> _pptxToPdf(
    List<List<String>> slideTexts,
    String output,
    ProgressCallback onProgress,
  ) async {
    final ttFont = await _loadFont();
    final pdfDoc = pw.Document();
    final total = slideTexts.length;

    const PdfColor accentColor = PdfColor.fromInt(0xFF1A3A5C);
    const PdfColor h2Color = PdfColor.fromInt(0xFF2E6DA4);
    const PdfColor bulletColor = PdfColor.fromInt(0xFF2E6DA4);
    const PdfColor bodyColor = PdfColor.fromInt(0xFF1A1A1A);
    const PdfColor ruleColor = PdfColor.fromInt(0xFFCCD6E0);

    for (int i = 0; i < total; i++) {
      final lines = slideTexts[i];
      final slideNumber = i + 1;

      final allText = lines.join(' ');
      final isRtl = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]',
      ).hasMatch(allText);
      final td = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
      final ca =
          isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;

      String titleText = 'Slide $slideNumber / $total';
      List<String> bodyLines = lines;
      if (lines.isNotEmpty) {
        final fk = _classifyLine(lines.first);
        if (fk == 'h1' || fk == 'h2') {
          titleText = lines.first.trim().replaceAll(RegExp(r'^#+\s*'), '');
          bodyLines = lines.skip(1).toList();
        }
      }

      final widgets = <pw.Widget>[];
      for (final raw in bodyLines) {
        final kind = _classifyLine(raw);
        final t = raw.trim();
        switch (kind) {
          case 'h2':
            final label = t.replaceAll(RegExp(r'^#+\s*'), '');
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(pw.Text(label.isEmpty ? ' ' : label,
                style: pw.TextStyle(
                    font: ttFont,
                    fontSize: 12,
                    color: h2Color,
                    fontWeight: pw.FontWeight.bold),
                textDirection: td));
            widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(top: 2, bottom: 4),
                height: 1.2,
                color: ruleColor));
            break;
          case 'bullet':
            final label = t.replaceFirst(RegExp(r'^[-•*]\s+'), '');
            widgets.add(pw.Padding(
                padding:
                    const pw.EdgeInsets.only(left: 10, top: 2, bottom: 2),
                child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                          width: 5,
                          height: 5,
                          margin:
                              const pw.EdgeInsets.only(top: 4, right: 8),
                          decoration: const pw.BoxDecoration(
                              color: bulletColor,
                              shape: pw.BoxShape.circle)),
                      pw.Expanded(
                          child: pw.Text(label,
                              style: pw.TextStyle(
                                  font: ttFont,
                                  fontSize: 11,
                                  color: bodyColor),
                              textDirection: td)),
                    ])));
            break;
          case 'numbered':
            final m = RegExp(r'^(\d+[.)]\s*)(.*)').firstMatch(t);
            final num = m?.group(1) ?? '';
            final label = m?.group(2) ?? t;
            widgets.add(pw.Padding(
                padding:
                    const pw.EdgeInsets.only(left: 10, top: 2, bottom: 2),
                child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(num,
                          style: pw.TextStyle(
                              font: ttFont,
                              fontSize: 11,
                              color: bulletColor,
                              fontWeight: pw.FontWeight.bold),
                          textDirection: td),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                          child: pw.Text(label,
                              style: pw.TextStyle(
                                  font: ttFont,
                                  fontSize: 11,
                                  color: bodyColor),
                              textDirection: td)),
                    ])));
            break;
          case 'blank':
            widgets.add(pw.SizedBox(height: 6));
            break;
          default:
            widgets.add(pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text(t.isEmpty ? ' ' : t,
                    style: pw.TextStyle(
                        font: ttFont, fontSize: 11, color: bodyColor),
                    textDirection: td)));
        }
      }

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 14, horizontal: 36),
                color: accentColor,
                child: pw.Text(
                  titleText,
                  style: pw.TextStyle(
                      font: ttFont,
                      fontSize: 16,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold),
                  textDirection: td,
                ),
              ),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(36, 20, 36, 24),
                  child: pw.Column(
                    crossAxisAlignment: ca,
                    children: widgets,
                  ),
                ),
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 36, vertical: 8),
                color: ruleColor,
                child: pw.Text(
                  '$slideNumber / $total',
                  style: pw.TextStyle(
                      font: ttFont,
                      fontSize: 9,
                      color: const PdfColor.fromInt(0xFF666666)),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      );

      onProgress(0.4 + 0.55 * (i + 1) / total);
    }

    final pdfBytes = await pdfDoc.save();
    if (pdfBytes.isEmpty) throw Exception('PPTX→PDF generation failed');
    await File(output).writeAsBytes(pdfBytes);
  }

  // ── Line classifier ───────────────────────────────────────────────────────

  // Returns: 'h1', 'h2', 'bullet', 'numbered', 'blank', 'body'
  String _classifyLine(String line) {
    if (line.trim().isEmpty) return 'blank';
    final t = line.trim();
    if (t.startsWith('### ')) return 'h2';
    if (t.startsWith('## ')) return 'h1';
    if (t.startsWith('# ')) return 'h1';
    if (t.length <= 60 &&
        t == t.toUpperCase() &&
        RegExp(r'[A-Z]').hasMatch(t)) return 'h1';
    if (t.endsWith(':') &&
        t.length <= 60 &&
        !t.startsWith('-') &&
        !t.startsWith('•')) return 'h2';
    if (RegExp(r'^-{3,}\s*Slide\s+\d+\s*-{3,}$').hasMatch(t)) return 'h1';
    if (RegExp(r'^[-=]{3,}$').hasMatch(t)) return 'blank';
    if (t.startsWith('- ') || t.startsWith('• ') || t.startsWith('* '))
      return 'bullet';
    if (RegExp(r'^\d+[.)]\s').hasMatch(t)) return 'numbered';
    return 'body';
  }

  // ── Text → PDF ────────────────────────────────────────────────────────────

  Future<void> _textToPdf(
    String text,
    String output,
    ProgressCallback onProgress,
  ) async {
    final content = text.trim().isEmpty ? '(empty)' : text;
    final lines = content.split('\n');

    final ttFont = await _loadFont();

    final bool isRtl = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(content);

    const PdfColor accentColor = PdfColor.fromInt(0xFF1A3A5C);
    const PdfColor h2Color = PdfColor.fromInt(0xFF2E6DA4);
    const PdfColor bulletColor = PdfColor.fromInt(0xFF2E6DA4);
    const PdfColor bodyColor = PdfColor.fromInt(0xFF1A1A1A);
    const PdfColor ruleColor = PdfColor.fromInt(0xFFCCD6E0);

    final td = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final ca =
        isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;

    List<pw.Widget> buildWidgets(List<String> chunk) {
      final widgets = <pw.Widget>[];
      for (final raw in chunk) {
        final kind = _classifyLine(raw);
        final t = raw.trim();
        switch (kind) {
          case 'h1':
            final label = t
                .replaceAll(RegExp(r'^#+\s*'), '')
                .replaceAll(RegExp(r'^-{3,}\s*'), '')
                .replaceAll(RegExp(r'\s*-{3,}$'), '');
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 6, horizontal: 10),
                decoration: const pw.BoxDecoration(
                  color: accentColor,
                  borderRadius:
                      pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  label.isEmpty ? ' ' : label,
                  style: pw.TextStyle(
                    font: ttFont,
                    fontSize: 14,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textDirection: td,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            break;

          case 'h2':
            final label = t.replaceAll(RegExp(r'^#+\s*'), '');
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(pw.Text(
              label.isEmpty ? ' ' : label,
              style: pw.TextStyle(
                font: ttFont,
                fontSize: 12,
                color: h2Color,
                fontWeight: pw.FontWeight.bold,
              ),
              textDirection: td,
            ));
            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 2, bottom: 4),
              height: 1.2,
              color: ruleColor,
            ));
            break;

          case 'bullet':
            final label = t.replaceFirst(RegExp(r'^[-•*]\s+'), '');
            widgets.add(pw.Padding(
              padding:
                  const pw.EdgeInsets.only(left: 12, top: 2, bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 5,
                    height: 5,
                    margin: const pw.EdgeInsets.only(top: 4, right: 8),
                    decoration: const pw.BoxDecoration(
                      color: bulletColor,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Expanded(
                      child: pw.Text(
                    label,
                    style: pw.TextStyle(
                        font: ttFont, fontSize: 11, color: bodyColor),
                    textDirection: td,
                  )),
                ],
              ),
            ));
            break;

          case 'numbered':
            final m = RegExp(r'^(\d+[.)]\s*)(.*)').firstMatch(t);
            final num = m?.group(1) ?? '';
            final label = m?.group(2) ?? t;
            widgets.add(pw.Padding(
              padding:
                  const pw.EdgeInsets.only(left: 12, top: 2, bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(num,
                      style: pw.TextStyle(
                          font: ttFont,
                          fontSize: 11,
                          color: bulletColor,
                          fontWeight: pw.FontWeight.bold),
                      textDirection: td),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                      child: pw.Text(
                    label,
                    style: pw.TextStyle(
                        font: ttFont, fontSize: 11, color: bodyColor),
                    textDirection: td,
                  )),
                ],
              ),
            ));
            break;

          case 'blank':
            widgets.add(pw.SizedBox(height: 6));
            break;

          default:
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                t.isEmpty ? ' ' : t,
                style: pw.TextStyle(
                    font: ttFont, fontSize: 11, color: bodyColor),
                textDirection: td,
              ),
            ));
        }
      }
      return widgets;
    }

    final pdfDoc = pw.Document();
    const linesPerPage = 45;
    final totalPages =
        (lines.length / linesPerPage).ceil().clamp(1, 99999);

    for (int start = 0; start < lines.length; start += linesPerPage) {
      final chunk = lines.skip(start).take(linesPerPage).toList();
      final pageIndex = start ~/ linesPerPage;
      final pageWidgets = buildWidgets(chunk);

      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
          build: (ctx) => pw.Column(
            crossAxisAlignment: ca,
            children: pageWidgets,
          ),
        ),
      );

      onProgress(0.4 + 0.5 * (pageIndex + 1) / totalPages);
    }

    final pdfBytes = await pdfDoc.save();
    if (pdfBytes.isEmpty) throw Exception('PDF generation failed');
    await File(output).writeAsBytes(pdfBytes);
  }

  // ── Write DOCX ────────────────────────────────────────────────────────────

  String _docxPara(String kind, String rawText) {
    final t = rawText.trim();
    switch (kind) {
      case 'h1':
        final label = _xmlEscape(t
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll(RegExp(r'^-{3,}\s*'), '')
            .replaceAll(RegExp(r'\s*-{3,}$'), ''));
        return '<w:p>'
            '<w:pPr><w:pStyle w:val="Heading1"/>'
            '<w:spacing w:before="240" w:after="120"/>'
            '</w:pPr>'
            '<w:r><w:t xml:space="preserve">${label.isEmpty ? " " : label}</w:t></w:r>'
            '</w:p>';

      case 'h2':
        final label = _xmlEscape(t.replaceAll(RegExp(r'^#+\s*'), ''));
        return '<w:p>'
            '<w:pPr><w:pStyle w:val="Heading2"/>'
            '<w:spacing w:before="180" w:after="80"/>'
            '</w:pPr>'
            '<w:r><w:t xml:space="preserve">${label.isEmpty ? " " : label}</w:t></w:r>'
            '</w:p>';

      case 'bullet':
        final label = _xmlEscape(t.replaceFirst(RegExp(r'^[-•*]\s+'), ''));
        return '<w:p>'
            '<w:pPr>'
            '<w:pStyle w:val="ListParagraph"/>'
            '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>'
            '<w:spacing w:before="40" w:after="40"/>'
            '</w:pPr>'
            '<w:r><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
            '<w:t xml:space="preserve">$label</w:t></w:r>'
            '</w:p>';

      case 'numbered':
        final m = RegExp(r'^(\d+[.)]\s*)(.*)').firstMatch(t);
        final label = _xmlEscape((m?.group(2) ?? t).trim());
        return '<w:p>'
            '<w:pPr>'
            '<w:pStyle w:val="ListParagraph"/>'
            '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="2"/></w:numPr>'
            '<w:spacing w:before="40" w:after="40"/>'
            '</w:pPr>'
            '<w:r><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
            '<w:t xml:space="preserve">$label</w:t></w:r>'
            '</w:p>';

      case 'blank':
        return '<w:p><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>';

      default:
        final label = _xmlEscape(t.isEmpty ? ' ' : t);
        return '<w:p>'
            '<w:pPr><w:spacing w:before="0" w:after="120" w:line="276" w:lineRule="auto"/></w:pPr>'
            '<w:r><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
            '<w:t xml:space="preserve">$label</w:t></w:r>'
            '</w:p>';
    }
  }

  Future<void> _writeDocx(
    String text,
    String output,
    ProgressCallback onProgress,
  ) async {
    final lines = (text.trim().isEmpty ? '(empty)' : text).split('\n');
    final body = lines.map((l) => _docxPara(_classifyLine(l), l)).join('\n');

    final docXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"\n'
        '            xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        '  <w:body>\n'
        '$body\n'
        '    <w:sectPr>\n'
        '      <w:pgSz w:w="11906" w:h="16838"/>\n'
        '      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1701" w:header="709" w:footer="709" w:gutter="0"/>\n'
        '    </w:sectPr>\n'
        '  </w:body>\n'
        '</w:document>';

    final stylesXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"\n'
        '          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n'
        '  <w:docDefaults>\n'
        '    <w:rPrDefault><w:rPr>\n'
        '      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>\n'
        '      <w:sz w:val="22"/><w:szCs w:val="22"/>\n'
        '      <w:color w:val="1A1A1A"/>\n'
        '    </w:rPr></w:rPrDefault>\n'
        '    <w:pPrDefault><w:pPr>\n'
        '      <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>\n'
        '    </w:pPr></w:pPrDefault>\n'
        '  </w:docDefaults>\n'
        '  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">\n'
        '    <w:name w:val="Normal"/><w:qFormat/>\n'
        '  </w:style>\n'
        '  <w:style w:type="paragraph" w:styleId="Heading1">\n'
        '    <w:name w:val="heading 1"/>\n'
        '    <w:basedOn w:val="Normal"/><w:qFormat/>\n'
        '    <w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/></w:pPr>\n'
        '    <w:rPr>\n'
        '      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>\n'
        '      <w:b/><w:bCs/>\n'
        '      <w:color w:val="1A3A5C"/>\n'
        '      <w:sz w:val="32"/><w:szCs w:val="32"/>\n'
        '    </w:rPr>\n'
        '  </w:style>\n'
        '  <w:style w:type="paragraph" w:styleId="Heading2">\n'
        '    <w:name w:val="heading 2"/>\n'
        '    <w:basedOn w:val="Normal"/><w:qFormat/>\n'
        '    <w:pPr><w:keepNext/><w:spacing w:before="180" w:after="80"/></w:pPr>\n'
        '    <w:rPr>\n'
        '      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>\n'
        '      <w:b/><w:bCs/>\n'
        '      <w:color w:val="2E6DA4"/>\n'
        '      <w:sz w:val="26"/><w:szCs w:val="26"/>\n'
        '    </w:rPr>\n'
        '  </w:style>\n'
        '  <w:style w:type="paragraph" w:styleId="ListParagraph">\n'
        '    <w:name w:val="List Paragraph"/>\n'
        '    <w:basedOn w:val="Normal"/><w:qFormat/>\n'
        '    <w:pPr><w:ind w:left="720"/></w:pPr>\n'
        '  </w:style>\n'
        '</w:styles>';

    final settingsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        '  <w:defaultTabStop w:val="720"/>\n'
        '  <w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat>\n'
        '</w:settings>';

    final numberingXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        '  <w:abstractNum w:abstractNumId="1">\n'
        '    <w:multiLevelType w:val="hybridMultilevel"/>\n'
        '    <w:lvl w:ilvl="0">\n'
        '      <w:start w:val="1"/><w:numFmt w:val="bullet"/>\n'
        '      <w:lvlText w:val="•"/>\n'
        '      <w:lvlJc w:val="left"/>\n'
        '      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>\n'
        '      <w:rPr><w:color w:val="2E6DA4"/><w:sz w:val="22"/></w:rPr>\n'
        '    </w:lvl>\n'
        '  </w:abstractNum>\n'
        '  <w:abstractNum w:abstractNumId="2">\n'
        '    <w:multiLevelType w:val="hybridMultilevel"/>\n'
        '    <w:lvl w:ilvl="0">\n'
        '      <w:start w:val="1"/><w:numFmt w:val="decimal"/>\n'
        '      <w:lvlText w:val="%1."/>\n'
        '      <w:lvlJc w:val="left"/>\n'
        '      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>\n'
        '      <w:rPr><w:color w:val="2E6DA4"/><w:b/><w:sz w:val="22"/></w:rPr>\n'
        '    </w:lvl>\n'
        '  </w:abstractNum>\n'
        '  <w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num>\n'
        '  <w:num w:numId="2"><w:abstractNumId w:val="2"/></w:num>\n'
        '</w:numbering>';

    final ctXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="xml" ContentType="application/xml"/>\n'
        '  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n'
        '  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\n'
        '  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>\n'
        '  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>\n'
        '</Types>';

    final relsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n'
        '</Relationships>';

    final wordRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
        '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>\n'
        '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>\n'
        '</Relationships>';

    final zipBytes = _createZip({
      '[Content_Types].xml': utf8.encode(ctXml),
      '_rels/.rels': utf8.encode(relsXml),
      'word/document.xml': utf8.encode(docXml),
      'word/styles.xml': utf8.encode(stylesXml),
      'word/settings.xml': utf8.encode(settingsXml),
      'word/numbering.xml': utf8.encode(numberingXml),
      'word/_rels/document.xml.rels': utf8.encode(wordRelsXml),
    });
    if (zipBytes.isEmpty) throw Exception('DOCX encoding failed');
    await File(output).writeAsBytes(zipBytes);
    onProgress(0.9);
  }

  // ── Write XLSX ────────────────────────────────────────────────────────────

  Future<void> _writeXlsx(String text, String output) async {
    final ex = excel_pkg.Excel.createExcel();
    final sheet = ex['Sheet1'];
    final lines = (text.trim().isEmpty ? ['(empty)'] : text.split('\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    for (final raw in lines) {
      final kind = _classifyLine(raw);
      String label;
      switch (kind) {
        case 'h1':
          label = raw
              .trim()
              .replaceAll(RegExp(r'^#+\s*'), '')
              .replaceAll(RegExp(r'^-{3,}\s*'), '')
              .replaceAll(RegExp(r'\s*-{3,}$'), '');
          break;
        case 'h2':
          label = raw.trim().replaceAll(RegExp(r'^#+\s*'), '');
          break;
        case 'bullet':
          label =
              '  • ${raw.trim().replaceFirst(RegExp(r'^[-•*]\s+'), '')}';
          break;
        case 'numbered':
          label = '  ${raw.trim()}';
          break;
        default:
          label = raw.trim();
      }

      final cell = excel_pkg.TextCellValue(label.isEmpty ? ' ' : label);
      final rowIdx = sheet.maxRows;
      sheet.appendRow([cell]);

      if (kind == 'h1' || kind == 'h2') {
        final cellStyle = excel_pkg.CellStyle(
          bold: true,
          backgroundColorHex: kind == 'h1'
              ? excel_pkg.ExcelColor.fromHexString('#1A3A5C')
              : excel_pkg.ExcelColor.fromHexString('#2E6DA4'),
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          fontSize: kind == 'h1' ? 13 : 11,
        );
        sheet
            .cell(excel_pkg.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIdx))
            .cellStyle = cellStyle;
      } else if (kind == 'bullet' || kind == 'numbered') {
        final cellStyle = excel_pkg.CellStyle(
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#1A1A1A'),
          fontSize: 10,
        );
        sheet
            .cell(excel_pkg.CellIndex.indexByColumnRow(
                columnIndex: 0, rowIndex: rowIdx))
            .cellStyle = cellStyle;
      }
    }

    sheet.setColumnWidth(0, 80);

    final b = ex.save();
    if (b == null) throw Exception('XLSX encode failed');
    await File(output).writeAsBytes(b);
  }

  // ── Write PPTX ────────────────────────────────────────────────────────────

  Future<void> _writePptx(
    String text,
    String output,
    ProgressCallback onProgress,
  ) async {
    final allLines =
        text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    const linesPerSlide = 15;
    final effective = allLines.isEmpty ? ['(empty)'] : allLines;

    const aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
    const pNs =
        'http://schemas.openxmlformats.org/presentationml/2006/main';
    const rNs =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const pkgNs =
        'http://schemas.openxmlformats.org/package/2006/relationships';
    const ctNs =
        'http://schemas.openxmlformats.org/package/2006/content-types';

    const officeDoc =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument';
    const slideRel =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide';
    const masterRel =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster';
    const layoutRel =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout';
    const presPropsRel =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps';

    const slideCt =
        'application/vnd.openxmlformats-officedocument.presentationml.slide+xml';
    const masterCt =
        'application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml';
    const layoutCt =
        'application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml';
    const presCt =
        'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml';
    const presProsCt =
        'application/vnd.openxmlformats-officedocument.presentationml.presProps+xml';

    final masterXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldMaster xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs">'
        '<p:cSld>'
        '<p:bg><p:bgRef idx="1001"><a:schemeClr clr="bg1"/></p:bgRef></p:bg>'
        '<p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '</p:spTree>'
        '</p:cSld>'
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" '
        'accent1="accent1" accent2="accent2" accent3="accent3" '
        'accent4="accent4" accent5="accent5" accent6="accent6" '
        'hlink="hlink" folHlink="folHlink"/>'
        '<p:sldLayoutIdLst>'
        '<p:sldLayoutId id="2147483649" r:id="rId_layout"/>'
        '</p:sldLayoutIdLst>'
        '<p:txStyles>'
        '<p:titleStyle><a:lvl1pPr algn="l"><a:defRPr lang="en-US" sz="3600" b="0"/></a:lvl1pPr></p:titleStyle>'
        '<p:bodyStyle><a:lvl1pPr><a:defRPr lang="en-US" sz="1800"/></a:lvl1pPr></p:bodyStyle>'
        '<p:otherStyle><a:lvl1pPr><a:defRPr lang="en-US" sz="1800"/></a:lvl1pPr></p:otherStyle>'
        '</p:txStyles>'
        '</p:sldMaster>';

    final masterRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
        '<Relationship Id="rId_layout" Type="$layoutRel" Target="../slideLayouts/slideLayout1.xml"/>'
        '</Relationships>';

    final layoutXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldLayout xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs" type="blank" preserve="1">'
        '<p:cSld name="Blank">'
        '<p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '</p:spTree>'
        '</p:cSld>'
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
        '</p:sldLayout>';

    final layoutRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
        '<Relationship Id="rId_master" Type="$masterRel" Target="../slideMasters/slideMaster1.xml"/>'
        '</Relationships>';

    final slideXmls = <String>[];
    for (int i = 0; i < effective.length; i += linesPerSlide) {
      final chunk = effective.skip(i).take(linesPerSlide).toList();
      final slideNum = i ~/ linesPerSlide + 1;

      String titleText;
      List<String> bodyLines;
      final firstKind = _classifyLine(chunk.first);
      if (firstKind == 'h1' || firstKind == 'h2') {
        titleText = chunk.first
            .trim()
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll(RegExp(r'^-{3,}\s*Slide\s+\d+\s*-{3,}$'),
                'Slide $slideNum');
        bodyLines = chunk.skip(1).toList();
      } else {
        titleText = 'Slide $slideNum';
        bodyLines = chunk;
      }

      final paras = StringBuffer();
      for (final raw in bodyLines) {
        final kind = _classifyLine(raw);
        final t = _xmlEscape(raw.trim());
        switch (kind) {
          case 'bullet':
            final label =
                _xmlEscape(raw.trim().replaceFirst(RegExp(r'^[-•*]\s+'), ''));
            paras.write(
              '<a:p>'
              '<a:pPr marL="342900" indent="-342900">'
              '<a:buChar char="•"/>'
              '</a:pPr>'
              '<a:r><a:rPr lang="en-US" dirty="0" sz="1600">'
              '<a:solidFill><a:srgbClr val="1A1A1A"/></a:solidFill>'
              '</a:rPr><a:t>$label</a:t></a:r></a:p>',
            );
            break;
          case 'numbered':
            final m = RegExp(r'^(\d+[.)]\s*)(.*)').firstMatch(raw.trim());
            final num = _xmlEscape(m?.group(1) ?? '');
            final label =
                _xmlEscape((m?.group(2) ?? raw.trim()).trim());
            paras.write(
              '<a:p>'
              '<a:pPr marL="342900" indent="-342900"><a:buNone/></a:pPr>'
              '<a:r><a:rPr lang="en-US" dirty="0" sz="1600" b="1">'
              '<a:solidFill><a:srgbClr val="2E6DA4"/></a:solidFill>'
              '</a:rPr><a:t>$num</a:t></a:r>'
              '<a:r><a:rPr lang="en-US" dirty="0" sz="1600">'
              '<a:solidFill><a:srgbClr val="1A1A1A"/></a:solidFill>'
              '</a:rPr><a:t>$label</a:t></a:r></a:p>',
            );
            break;
          case 'h2':
            final label = _xmlEscape(
                raw.trim().replaceAll(RegExp(r'^#+\s*'), ''));
            paras.write(
              '<a:p><a:pPr><a:buNone/></a:pPr>'
              '<a:r><a:rPr lang="en-US" dirty="0" sz="1800" b="1">'
              '<a:solidFill><a:srgbClr val="2E6DA4"/></a:solidFill>'
              '</a:rPr><a:t>$label</a:t></a:r></a:p>',
            );
            break;
          case 'blank':
            paras.write(
                '<a:p><a:endParaRPr lang="en-US" dirty="0" sz="1400"/></a:p>');
            break;
          default:
            if (t.isEmpty) {
              paras.write(
                  '<a:p><a:endParaRPr lang="en-US" dirty="0" sz="1400"/></a:p>');
            } else {
              paras.write(
                '<a:p><a:pPr><a:buNone/></a:pPr>'
                '<a:r><a:rPr lang="en-US" dirty="0" sz="1600">'
                '<a:solidFill><a:srgbClr val="1A1A1A"/></a:solidFill>'
                '</a:rPr><a:t>$t</a:t></a:r></a:p>',
              );
            }
        }
      }

      final escapedTitle =
          _xmlEscape(titleText.isEmpty ? 'Slide $slideNum' : titleText);

      slideXmls.add(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sld xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs">'
        '<p:cSld>'
        '<p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
        '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '<p:sp>'
        '<p:nvSpPr>'
        '<p:cNvPr id="2" name="TitleBg"/>'
        '<p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>'
        '<p:nvPr/>'
        '</p:nvSpPr>'
        '<p:spPr>'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="9144000" cy="1143000"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="1A3A5C"/></a:solidFill>'
        '</p:spPr>'
        '<p:txBody>'
        '<a:bodyPr lIns="457200" tIns="180000" rIns="457200" bIns="91440" anchor="ctr"/>'
        '<a:lstStyle/>'
        '<a:p><a:r>'
        '<a:rPr lang="en-US" dirty="0" sz="2400" b="1">'
        '<a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill>'
        '</a:rPr>'
        '<a:t>$escapedTitle</a:t>'
        '</a:r></a:p>'
        '</p:txBody>'
        '</p:sp>'
        '<p:sp>'
        '<p:nvSpPr>'
        '<p:cNvPr id="3" name="ContentBox"/>'
        '<p:cNvSpPr txBox="1"><a:spLocks noGrp="1"/></p:cNvSpPr>'
        '<p:nvPr/>'
        '</p:nvSpPr>'
        '<p:spPr>'
        '<a:xfrm><a:off x="457200" y="1280000"/>'
        '<a:ext cx="8229600" cy="4800000"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:noFill/>'
        '</p:spPr>'
        '<p:txBody>'
        '<a:bodyPr wrap="square" lIns="91440" tIns="45720" rIns="91440" bIns="45720" anchor="t"/>'
        '<a:lstStyle/>'
        '${paras.isEmpty ? "<a:p><a:endParaRPr/></a:p>" : paras.toString()}'
        '</p:txBody>'
        '</p:sp>'
        '<p:sp>'
        '<p:nvSpPr>'
        '<p:cNvPr id="4" name="SlideNum"/>'
        '<p:cNvSpPr txBox="1"><a:spLocks noGrp="1"/></p:cNvSpPr>'
        '<p:nvPr/>'
        '</p:nvSpPr>'
        '<p:spPr>'
        '<a:xfrm><a:off x="7620000" y="6400000"/>'
        '<a:ext cx="1524000" cy="304800"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:noFill/>'
        '</p:spPr>'
        '<p:txBody>'
        '<a:bodyPr anchor="ctr"/><a:lstStyle/>'
        '<a:p><a:pPr algn="r"/>'
        '<a:r><a:rPr lang="en-US" dirty="0" sz="1000">'
        '<a:solidFill><a:srgbClr val="888888"/></a:solidFill>'
        '</a:rPr>'
        '<a:t>$slideNum / ${(effective.length / linesPerSlide).ceil()}</a:t>'
        '</a:r></a:p>'
        '</p:txBody>'
        '</p:sp>'
        '</p:spTree>'
        '</p:cSld>'
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
        '</p:sld>',
      );
    }

    final n = slideXmls.length;

    String slideRelsXml(int idx) =>
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
        '<Relationship Id="rId_layout" Type="$layoutRel" Target="../slideLayouts/slideLayout1.xml"/>'
        '</Relationships>';

    final slideRefs = List.generate(
        n, (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 1}"/>').join('');
    final presRelsList = List.generate(
        n,
        (i) =>
            '<Relationship Id="rId${i + 1}" Type="$slideRel" Target="slides/slide${i + 1}.xml"/>').join('');
    final slideOverrides = List.generate(
        n,
        (i) =>
            '<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="$slideCt"/>').join('');

    final files = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="$ctNs">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/ppt/presentation.xml" ContentType="$presCt"/>'
        '<Override PartName="/ppt/presProps.xml" ContentType="$presProsCt"/>'
        '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="$masterCt"/>'
        '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="$layoutCt"/>'
        '$slideOverrides'
        '</Types>',
      ),
      '_rels/.rels': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
        '<Relationship Id="rId1" Type="$officeDoc" Target="ppt/presentation.xml"/>'
        '</Relationships>',
      ),
      'ppt/presentation.xml': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:presentation xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs">'
        '<p:sldMasterIdLst>'
        '<p:sldMasterId id="2147483648" r:id="rId_master"/>'
        '</p:sldMasterIdLst>'
        '<p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>'
        '<p:notesSz cx="6858000" cy="9144000"/>'
        '<p:sldIdLst>$slideRefs</p:sldIdLst>'
        '<p:defaultTextStyle/>'
        '</p:presentation>',
      ),
      'ppt/presProps.xml': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:presentationPr xmlns:p="$pNs"><p:extLst/></p:presentationPr>',
      ),
      'ppt/_rels/presentation.xml.rels': utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
        '$presRelsList'
        '<Relationship Id="rId${n + 1}" Type="$presPropsRel" Target="presProps.xml"/>'
        '<Relationship Id="rId_master" Type="$masterRel" Target="slideMasters/slideMaster1.xml"/>'
        '</Relationships>',
      ),
      'ppt/slideMasters/slideMaster1.xml': utf8.encode(masterXml),
      'ppt/slideMasters/_rels/slideMaster1.xml.rels':
          utf8.encode(masterRelsXml),
      'ppt/slideLayouts/slideLayout1.xml': utf8.encode(layoutXml),
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels':
          utf8.encode(layoutRelsXml),
    };

    for (int i = 0; i < slideXmls.length; i++) {
      files['ppt/slides/slide${i + 1}.xml'] = utf8.encode(slideXmls[i]);
      files['ppt/slides/_rels/slide${i + 1}.xml.rels'] =
          utf8.encode(slideRelsXml(i));
      onProgress(0.3 + 0.6 * (i + 1) / slideXmls.length);
    }

    final zipBytes = _createZip(files);
    if (zipBytes.isEmpty) throw Exception('PPTX encoding failed');
    await File(output).writeAsBytes(zipBytes);
    onProgress(0.9);
  }

  // ── Validation ────────────────────────────────────────────────────────────

  void _assertTextNotEmpty(String text, String sourceFormat) {
    if (text.trim().isEmpty) {
      throw Exception(
        '$sourceFormat extraction returned no content. '
        'The file may be encrypted, corrupted, or contain only images.',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _escapeCsv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  List<int> _createZip(Map<String, List<int>> files) {
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('ZIP encoding failed');
    return encoded;
  }

  List<List<String>> _parseCsvRows(String content) {
    final rows = <List<String>>[];
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final fields = <String>[];
      final cur = StringBuffer();
      bool inQ = false;
      for (int i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          if (inQ && i + 1 < line.length && line[i + 1] == '"') {
            cur.write('"');
            i++;
          } else {
            inQ = !inQ;
          }
        } else if (ch == ',' && !inQ) {
          fields.add(cur.toString());
          cur.clear();
        } else {
          cur.write(ch);
        }
      }
      fields.add(cur.toString());
      rows.add(fields);
    }
    return rows;
  }
}