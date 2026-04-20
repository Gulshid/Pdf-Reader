// ignore_for_file: unused_import

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../shared/models/conversion_task_model.dart';
import 'file_utils.dart';

typedef ProgressCallback = void Function(double progress);

class ConversionService {
  const ConversionService();

  /// Main entry point. Dispatches to correct converter.
  Future<String> convert({
    required ConversionTaskModel task,
    required ProgressCallback onProgress,
  }) async {
    final outputPath =
        await FileUtils.buildOutputPath(task.sourceFilePath, task.targetFormat);

    onProgress(0.1);

    switch (task.sourceFormat) {
      case SupportedFormat.pdf:
        await _fromPdf(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.txt:
        await _fromTxt(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.jpg:
      case SupportedFormat.png:
        await _fromImage(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.csv:
        await _fromCsv(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.xlsx:
        await _fromXlsx(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.docx:
        await _fromDocx(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
    }

    onProgress(1.0);
    return outputPath;
  }

  // ── PDF → TXT / JPG / PNG ──────────────────────────────────────────────────

  Future<void> _fromPdf(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    final sfDoc = sf.PdfDocument(inputBytes: bytes);

    onProgress(0.3);

    switch (target) {
      case SupportedFormat.txt:
        final buffer = StringBuffer();
        for (int i = 0; i < sfDoc.pages.count; i++) {
          final extractor = sf.PdfTextExtractor(sfDoc);
          buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
          onProgress(0.3 + 0.6 * (i / sfDoc.pages.count));
        }
        sfDoc.dispose();
        await File(output).writeAsString(buffer.toString());

      case SupportedFormat.jpg:
      case SupportedFormat.png:
        // Render first page as image using syncfusion (not directly supported)
        // You may need to use a different package like 'pdf_render' for PDF to image conversion.
        // Here, we throw an error to indicate this is not supported with syncfusion.
        sfDoc.dispose();
        throw UnsupportedError('PDF to image conversion is not supported with Syncfusion PDF. Use a package like pdf_render or native code for this feature.');

      default:
        throw UnsupportedError('PDF → ${target.label} not supported');
    }
  }

  // ── TXT → PDF ──────────────────────────────────────────────────────────────

  Future<void> _fromTxt(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    if (target != SupportedFormat.pdf) {
      throw UnsupportedError('TXT → ${target.label} not supported');
    }
    final text = await File(src).readAsString();
    onProgress(0.4);

    final pdfDoc = pw.Document();
    final lines = text.split('\n');
    const linesPerPage = 50;

    for (int i = 0; i < lines.length; i += linesPerPage) {
      final pageLines = lines.skip(i).take(linesPerPage).toList();
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: pageLines
                .map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 12)))
                .toList(),
          ),
        ),
      );
      onProgress(0.4 + 0.5 * (i / lines.length));
    }

    await File(output).writeAsBytes(await pdfDoc.save());
  }

  // ── Image → PDF ────────────────────────────────────────────────────────────

  Future<void> _fromImage(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    if (target != SupportedFormat.pdf) {
      // Image format conversion (JPG ↔ PNG)
      final bytes = await File(src).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');
      onProgress(0.5);
      if (target == SupportedFormat.jpg) {
        await File(output).writeAsBytes(img.encodeJpg(decoded, quality: 90));
      } else if (target == SupportedFormat.png) {
        await File(output).writeAsBytes(img.encodePng(decoded));
      }
      return;
    }

    final bytes = await File(src).readAsBytes();
    final pdfImage = pw.MemoryImage(bytes);
    onProgress(0.4);

    final pdfDoc = pw.Document();
    pdfDoc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Center(
          child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
        ),
      ),
    );

    await File(output).writeAsBytes(await pdfDoc.save());
  }

  // ── CSV → PDF / XLSX ───────────────────────────────────────────────────────

  Future<void> _fromCsv(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final content = await File(src).readAsString();
    onProgress(0.3);

    if (target == SupportedFormat.pdf) {
      final rows = content.split('\n').map((r) => r.split(',')).toList();
      final pdfDoc = pw.Document();
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.TableHelper.fromTextArray(
            data: rows,
            border: pw.TableBorder.all(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      await File(output).writeAsBytes(await pdfDoc.save());
    } else {
      throw UnsupportedError('CSV → ${target.label} not supported');
    }
  }

  // ── XLSX → PDF ─────────────────────────────────────────────────────────────

  Future<void> _fromXlsx(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    throw UnsupportedError('XLSX conversion coming soon');
  }

  // ── DOCX → PDF ─────────────────────────────────────────────────────────────

  Future<void> _fromDocx(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    throw UnsupportedError('DOCX conversion coming soon');
  }
}