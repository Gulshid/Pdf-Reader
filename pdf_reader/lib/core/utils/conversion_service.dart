import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:docx_to_text/docx_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../shared/models/conversion_task_model.dart';
import 'file_utils.dart';

typedef ProgressCallback = void Function(double progress);

class ConversionService {
  const ConversionService();

  Future<String> convert({
    required ConversionTaskModel task,
    required ProgressCallback onProgress,
  }) async {
    final outputPath = await FileUtils.buildOutputPath(
      task.sourceFilePath,
      task.targetFormat,
    );

    final outDir = Directory(p.dirname(outputPath));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

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
      case SupportedFormat.pptx:
        await _fromPptx(task.sourceFilePath, task.targetFormat, outputPath, onProgress);
    }

    onProgress(1.0);

    final outFile = File(outputPath);
    if (!outFile.existsSync()) {
      throw Exception('Output file was not created. Check storage permissions.');
    }
    if (outFile.lengthSync() == 0) {
      throw Exception('Output file is empty.');
    }

    return outputPath;
  }

  // ── PDF → * ───────────────────────────────────────────────────────────────

  Future<void> _fromPdf(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    switch (target) {
      case SupportedFormat.txt:
        final text = await _extractTextFromPdf(src, onProgress);
        await File(output).writeAsString(text, encoding: utf8);

      case SupportedFormat.jpg:
      case SupportedFormat.png:
        final document = await pdfx.PdfDocument.openFile(src);
        onProgress(0.3);
        try {
          final page = await document.getPage(1);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: target == SupportedFormat.jpg
                ? pdfx.PdfPageImageFormat.jpeg
                : pdfx.PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          await page.close();
          onProgress(0.8);
          if (pageImage == null) throw Exception('Failed to render PDF page.');
          await File(output).writeAsBytes(pageImage.bytes);
        } finally {
          await document.close();
        }

      case SupportedFormat.docx:
        final text = await _extractTextFromPdf(src, onProgress);
        await _writeDocx(text, output, onProgress);

      case SupportedFormat.xlsx:
        final text = await _extractTextFromPdf(src, onProgress);
        await _writeXlsx(text, output);

      case SupportedFormat.csv:
        final text = await _extractTextFromPdf(src, onProgress);
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
        final csv = lines.map((l) => _escapeCsv(l.trim())).join('\n');
        await File(output).writeAsString(csv, encoding: utf8);

      case SupportedFormat.pptx:
        final text = await _extractTextFromPdf(src, onProgress);
        await _writePptx(text, output, onProgress);

      default:
        throw UnsupportedError('PDF → ${target.label} not supported');
    }
  }

  /// Extract text from PDF.
  /// Step 1: Try Syncfusion text extraction (fast, works for text-based PDFs).
  /// Step 2: If the PDF is scanned/image-only, fall back to ML Kit OCR —
  ///         renders each page via pdfx, saves as a temp PNG, runs OCR on it.
  Future<String> _extractTextFromPdf(
      String src, ProgressCallback onProgress) async {
    final bytes = await File(src).readAsBytes();
    final sfDoc = sf.PdfDocument(inputBytes: bytes);
    onProgress(0.2);

    // ── Step 1: Syncfusion text extraction ───────────────────────────────────
    final buffer = StringBuffer();
    final extractor = sf.PdfTextExtractor(sfDoc);
    final pageCount = sfDoc.pages.count;
    for (int i = 0; i < pageCount; i++) {
      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      if (pageText.trim().isNotEmpty) buffer.writeln(pageText);
      onProgress(0.2 + 0.3 * (i + 1) / pageCount);
    }
    sfDoc.dispose();

    final directText = buffer.toString().trim();
    if (directText.isNotEmpty) return directText;

    // ── Step 2: OCR fallback for scanned/image PDFs ──────────────────────────
    // Render each page to a PNG image, then run ML Kit on-device OCR.
    // No internet required — ML Kit runs fully offline on Android.
    final ocrBuffer = StringBuffer();
    final pdfxDoc = await pdfx.PdfDocument.openFile(src);
    final tempDir = await getTemporaryDirectory();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      for (int i = 1; i <= pdfxDoc.pagesCount; i++) {
        final page = await pdfxDoc.getPage(i);
        // Render at 2× for better OCR accuracy
        final rendered = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (rendered == null) continue;

        // Save temp PNG so ML Kit can read it from disk
        final tmpFile = File(p.join(tempDir.path, 'ocr_page_$i.png'));
        await tmpFile.writeAsBytes(rendered.bytes);

        final inputImage = InputImage.fromFile(tmpFile);
        final recognizedText = await recognizer.processImage(inputImage);
        if (recognizedText.text.trim().isNotEmpty) {
          ocrBuffer.writeln(recognizedText.text);
        }

        // Clean up temp file
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
      case SupportedFormat.docx:
        await _writeDocx(text, output, onProgress);
      case SupportedFormat.xlsx:
        onProgress(0.5);
        await _writeXlsx(text, output);
      case SupportedFormat.pptx:
        await _writePptx(text, output, onProgress);
      default:
        throw UnsupportedError('TXT → ${target.label} not supported');
    }
  }

  // ── Image → * ────────────────────────────────────────────────────────────

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
        final pdfDoc = pw.Document();
        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) =>
              pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
        ));
        onProgress(0.7);
        final pdfBytes = await pdfDoc.save();
        if (pdfBytes.isEmpty) throw Exception('PDF generation failed');
        await File(output).writeAsBytes(pdfBytes);

      case SupportedFormat.jpg:
        if (src.toLowerCase().endsWith('.jpg') || src.toLowerCase().endsWith('.jpeg')) {
          await File(output).writeAsBytes(bytes);
        } else {
          final d = img.decodeImage(bytes);
          if (d == null) throw Exception('Cannot decode image');
          await File(output).writeAsBytes(img.encodeJpg(d, quality: 90));
        }

      case SupportedFormat.png:
        if (src.toLowerCase().endsWith('.png')) {
          await File(output).writeAsBytes(bytes);
        } else {
          final d = img.decodeImage(bytes);
          if (d == null) throw Exception('Cannot decode image');
          await File(output).writeAsBytes(img.encodePng(d));
        }

      default:
        throw UnsupportedError('Image → ${target.label} not supported');
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
        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.TableHelper.fromTextArray(
            data: data,
            border: pw.TableBorder.all(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle:
                pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ));
        onProgress(0.7);
        await File(output).writeAsBytes(await pdfDoc.save());

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

      case SupportedFormat.txt:
        final lines = data.map((r) => r.join('\t')).join('\n');
        await File(output).writeAsString(lines, encoding: utf8);

      default:
        throw UnsupportedError('CSV → ${target.label} not supported');
    }
  }

  // ── XLSX → * ──────────────────────────────────────────────────────────────

  Future<void> _fromXlsx(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final bytes = await File(src).readAsBytes();
    onProgress(0.3);
    final ex = excel_pkg.Excel.decodeBytes(bytes);
    if (ex.tables.isEmpty) throw Exception('XLSX has no sheets');
    final sheet = ex.tables[ex.tables.keys.first]!;
    onProgress(0.5);
    final rows = sheet.rows
        .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();
    final data = rows.isEmpty ? [['(empty)']] : rows;

    switch (target) {
      case SupportedFormat.pdf:
        final pdfDoc = pw.Document();
        pdfDoc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.TableHelper.fromTextArray(
            data: data,
            border: pw.TableBorder.all(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ));
        onProgress(0.8);
        await File(output).writeAsBytes(await pdfDoc.save());

      case SupportedFormat.csv:
        final csv = data.map((r) => r.map(_escapeCsv).join(',')).join('\n');
        await File(output).writeAsString(csv, encoding: utf8);

      case SupportedFormat.txt:
        final txt = data.map((r) => r.join('\t')).join('\n');
        await File(output).writeAsString(txt, encoding: utf8);

      default:
        throw UnsupportedError('XLSX → ${target.label} not supported');
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
    onProgress(0.3);
    String text;
    try {
      text = docxToText(bytes); // bytes is already Uint8List — cast removed (was crashing silently)
    } catch (_) {
      text = '';
    }
    if (text.trim().isEmpty) {
      text = 'This DOCX has no extractable text.';
    }
    onProgress(0.6);

    switch (target) {
      case SupportedFormat.pdf:
        await _textToPdf(text, output, onProgress);
      case SupportedFormat.txt:
        await File(output).writeAsString(text, encoding: utf8);
      case SupportedFormat.xlsx:
        await _writeXlsx(text, output);
      default:
        throw UnsupportedError('DOCX → ${target.label} not supported');
    }
  }

  // ── PPTX → * ─────────────────────────────────────────────────────────────

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
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final buf = StringBuffer();
    for (final slide in slideFiles) {
      final xml = utf8.decode(slide.content, allowMalformed: true);
      for (final m in RegExp(r'<a:t[^>]*>([^<]*)<\/a:t>').allMatches(xml)) {
        final t = m.group(1)?.trim();
        if (t != null && t.isNotEmpty) buf.writeln(t);
      }
      buf.writeln();
    }
    onProgress(0.6);
    final text = buf.toString().trim().isEmpty
        ? 'No extractable text in this PPTX.'
        : buf.toString();

    switch (target) {
      case SupportedFormat.pdf:
        await _textToPdf(text, output, onProgress);
      case SupportedFormat.txt:
        await File(output).writeAsString(text, encoding: utf8);
      default:
        throw UnsupportedError('PPTX → ${target.label} not supported');
    }
  }

  // ── Text → PDF (Syncfusion) ───────────────────────────────────────────────
  // Uses Syncfusion instead of the `pdf` package because Syncfusion supports
  // Unicode (Arabic/Urdu) natively. PdfStandardFont uses system glyph fallback.

  Future<void> _textToPdf(
      String text, String output, ProgressCallback onProgress) async {
    final lines = (text.trim().isEmpty ? '(empty)' : text).split('\n');
    final sfDoc = sf.PdfDocument();
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 11);
    final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));

    sf.PdfPage page = sfDoc.pages.add();
    double y = 30;
    const double lh = 16;
    final double maxY = page.getClientSize().height - 30;
    final double pageW = page.getClientSize().width - 60;

    for (int i = 0; i < lines.length; i++) {
      if (y + lh > maxY) {
        page = sfDoc.pages.add();
        y = 30;
      }
      final line = lines[i];
      if (line.trim().isNotEmpty) {
        page.graphics.drawString(
          line,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(30, y, pageW, lh),
        );
      }
      y += lh;
      if (lines.length > 1) onProgress(0.4 + 0.5 * (i / lines.length));
    }

    final pdfBytes = await sfDoc.save();
    sfDoc.dispose();
    if (pdfBytes.isEmpty) throw Exception('PDF generation failed');
    await File(output).writeAsBytes(pdfBytes);
  }

  // ── Write DOCX ────────────────────────────────────────────────────────────
  // FIX: Removed mc:Ignorable="w14" which referenced undeclared xmlns:w14.
  // This was causing WPS/Word Mobile to show blank or "corrupt file" errors.

  Future<void> _writeDocx(
      String text, String output, ProgressCallback onProgress) async {
    final body = (text.trim().isEmpty ? '(empty)' : text)
        .split('\n')
        .map(_xmlEscape)
        .map((l) =>
            '<w:p><w:r><w:t xml:space="preserve">$l</w:t></w:r></w:p>')
        .join('\n');

    // CRITICAL: No mc:Ignorable here — it was referencing undeclared w14 namespace
    // which made strict XML parsers (WPS, Word Mobile) reject the document.
    final docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$body
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="1701" w:header="709" w:footer="709" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr><w:spacing w:after="160" w:line="259" w:lineRule="auto"/></w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
  </w:style>
</w:styles>''';

    final settingsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:defaultTabStop w:val="720"/>
  <w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat>
</w:settings>''';

    final ctXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final wordRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
</Relationships>''';

    final zipBytes = _createZip({
      '[Content_Types].xml': utf8.encode(ctXml),
      '_rels/.rels': utf8.encode(relsXml),
      'word/document.xml': utf8.encode(docXml),
      'word/styles.xml': utf8.encode(stylesXml),
      'word/settings.xml': utf8.encode(settingsXml),
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
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      sheet.appendRow([excel_pkg.TextCellValue('(empty)')]);
    } else {
      for (final l in lines) {
        sheet.appendRow([excel_pkg.TextCellValue(l)]);
      }
    }
    final b = ex.save();
    if (b == null) throw Exception('XLSX encode failed');
    await File(output).writeAsBytes(b);
  }

  // ── Write PPTX ────────────────────────────────────────────────────────────
  //
  // A valid PPTX requires this exact chain of relationships:
  //   presentation.xml
  //     └─ slideMaster1.xml   (master — defines colour map, default text styles)
  //           └─ slideLayout1.xml  (layout — defines placeholder geometry)
  //                 └─ slide1..N.xml  (each slide links back to the layout)
  //
  // Missing ANY link in this chain causes PowerPoint / WPS / LibreOffice to
  // report the file as corrupt.  Previous versions omitted the layout entirely
  // and left slide .rels files empty — those are the bugs fixed here.

  Future<void> _writePptx(
      String text, String output, ProgressCallback onProgress) async {
    final allLines =
        text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    const linesPerSlide = 15;
    final effective = allLines.isEmpty ? ['(empty)'] : allLines;

    // ── Namespaces used in every PPTX XML file ──────────────────────────────
    const aNs  = 'http://schemas.openxmlformats.org/drawingml/2006/main';
    const pNs  = 'http://schemas.openxmlformats.org/presentationml/2006/main';
    const rNs  = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const pkgNs = 'http://schemas.openxmlformats.org/package/2006/relationships';
    const ctNs  = 'http://schemas.openxmlformats.org/package/2006/content-types';

    // ── Relationship type URIs ───────────────────────────────────────────────
    const officeDoc = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument';
    const slideRel     = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide';
    const masterRel    = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster';
    const layoutRel    = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout';
    const presPropsRel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps';

    // ── Content-type values ──────────────────────────────────────────────────
    const slideCt  = 'application/vnd.openxmlformats-officedocument.presentationml.slide+xml';
    const masterCt = 'application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml';
    const layoutCt = 'application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml';
    const presCt   = 'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml';
    const presProsCt = 'application/vnd.openxmlformats-officedocument.presentationml.presProps+xml';

    // ── Slide master ─────────────────────────────────────────────────────────
    // Minimal but complete: white background, colour map, empty layout list,
    // and default text styles so slides can resolve font sizes.
    final masterXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldMaster xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs">'
        '<p:cSld>'
          '<p:bg><p:bgRef idx="1001"><a:schemeClr clr="bg1"/></p:bgRef></p:bg>'
          '<p:spTree>'
            '<p:nvGrpSpPr>'
              '<p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
            '</p:nvGrpSpPr>'
            '<p:grpSpPr>'
              '<a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
              '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm>'
            '</p:grpSpPr>'
          '</p:spTree>'
        '</p:cSld>'
        '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" '
          'accent1="accent1" accent2="accent2" accent3="accent3" '
          'accent4="accent4" accent5="accent5" accent6="accent6" '
          'hlink="hlink" folHlink="folHlink"/>'
        // sldLayoutIdLst must list our one layout
        '<p:sldLayoutIdLst>'
          '<p:sldLayoutId id="2147483649" r:id="rId_layout"/>'
        '</p:sldLayoutIdLst>'
        '<p:txStyles>'
          '<p:titleStyle><a:lvl1pPr algn="l"><a:defRPr lang="en-US" sz="3600" b="0"/></a:lvl1pPr></p:titleStyle>'
          '<p:bodyStyle><a:lvl1pPr><a:defRPr lang="en-US" sz="1800"/></a:lvl1pPr></p:bodyStyle>'
          '<p:otherStyle><a:lvl1pPr><a:defRPr lang="en-US" sz="1800"/></a:lvl1pPr></p:otherStyle>'
        '</p:txStyles>'
        '</p:sldMaster>';

    // Master .rels — references the slide layout
    final masterRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
          '<Relationship Id="rId_layout" Type="$layoutRel" Target="../slideLayouts/slideLayout1.xml"/>'
        '</Relationships>';

    // ── Slide layout ─────────────────────────────────────────────────────────
    // "Blank" layout — no placeholder shapes.  Slides that do not use a title
    // placeholder won't trigger a missing-placeholder validation error.
    final layoutXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sldLayout xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs" type="blank" preserve="1">'
        '<p:cSld name="Blank">'
          '<p:spTree>'
            '<p:nvGrpSpPr>'
              '<p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
            '</p:nvGrpSpPr>'
            '<p:grpSpPr>'
              '<a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
              '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm>'
            '</p:grpSpPr>'
          '</p:spTree>'
        '</p:cSld>'
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
        '</p:sldLayout>';

    // Layout .rels — must point back to its master
    final layoutRelsXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
          '<Relationship Id="rId_master" Type="$masterRel" Target="../slideMasters/slideMaster1.xml"/>'
        '</Relationships>';

    // ── Build slides ─────────────────────────────────────────────────────────
    final slideXmls = <String>[];

    for (int i = 0; i < effective.length; i += linesPerSlide) {
      final chunk = effective.skip(i).take(linesPerSlide).toList();
      final paras = chunk
          .map(_xmlEscape)
          .map((l) => '<a:p><a:r><a:rPr lang="en-US" dirty="0" sz="1800"/><a:t>$l</a:t></a:r></a:p>')
          .join('');

      // Use an explicit text box (not a placeholder) so no layout
      // placeholder resolution is needed.
      slideXmls.add(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sld xmlns:a="$aNs" xmlns:p="$pNs" xmlns:r="$rNs">'
        '<p:cSld>'
          '<p:spTree>'
            '<p:nvGrpSpPr>'
              '<p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
            '</p:nvGrpSpPr>'
            '<p:grpSpPr>'
              '<a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
              '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm>'
            '</p:grpSpPr>'
            // Explicit text box — no <p:ph> so layout lookup is not triggered
            '<p:sp>'
              '<p:nvSpPr>'
                '<p:cNvPr id="2" name="TextBox"/>'
                '<p:cNvSpPr txBox="1"><a:spLocks noGrp="1"/></p:cNvSpPr>'
                '<p:nvPr/>'
              '</p:nvSpPr>'
              '<p:spPr>'
                '<a:xfrm><a:off x="457200" y="457200"/>'
                '<a:ext cx="8229600" cy="5486400"/></a:xfrm>'
                '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
                '<a:noFill/>'
              '</p:spPr>'
              '<p:txBody>'
                '<a:bodyPr wrap="square" lIns="91440" tIns="45720" rIns="91440" bIns="45720" anchor="t"/>'
                '<a:lstStyle/>'
                '$paras'
              '</p:txBody>'
            '</p:sp>'
          '</p:spTree>'
        '</p:cSld>'
        // clrMapOvr must use masterClrMapping — links to master colour scheme
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
        '</p:sld>'
      );
    }

    final n = slideXmls.length;

    // Each slide's .rels must reference its slide layout
    String slideRelsXml(int slideIdx) =>
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$pkgNs">'
          '<Relationship Id="rId_layout" Type="$layoutRel" Target="../slideLayouts/slideLayout1.xml"/>'
        '</Relationships>';

    final slideRefs = List.generate(
        n, (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 1}"/>').join('');
    final presRelsList = List.generate(
        n,
        (i) => '<Relationship Id="rId${i + 1}" Type="$slideRel" Target="slides/slide${i + 1}.xml"/>').join('');
    final slideOverrides = List.generate(
        n,
        (i) => '<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="$slideCt"/>').join('');

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
          '</Types>'),

      '_rels/.rels': utf8.encode(
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="$pkgNs">'
            '<Relationship Id="rId1" Type="$officeDoc" Target="ppt/presentation.xml"/>'
          '</Relationships>'),

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
          '</p:presentation>'),

      'ppt/presProps.xml': utf8.encode(
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<p:presentationPr xmlns:p="$pNs"><p:extLst/></p:presentationPr>'),

      'ppt/_rels/presentation.xml.rels': utf8.encode(
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="$pkgNs">'
            '$presRelsList'
            '<Relationship Id="rId${n + 1}" Type="$presPropsRel" Target="presProps.xml"/>'
            '<Relationship Id="rId_master" Type="$masterRel" Target="slideMasters/slideMaster1.xml"/>'
          '</Relationships>'),

      'ppt/slideMasters/slideMaster1.xml': utf8.encode(masterXml),
      'ppt/slideMasters/_rels/slideMaster1.xml.rels': utf8.encode(masterRelsXml),

      'ppt/slideLayouts/slideLayout1.xml': utf8.encode(layoutXml),
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels': utf8.encode(layoutRelsXml),
    };

    for (int i = 0; i < slideXmls.length; i++) {
      files['ppt/slides/slide${i + 1}.xml'] = utf8.encode(slideXmls[i]);
      files['ppt/slides/_rels/slide${i + 1}.xml.rels'] = utf8.encode(slideRelsXml(i));
      onProgress(0.3 + 0.6 * (i + 1) / slideXmls.length);
    }

    final zipBytes = _createZip(files);
    if (zipBytes.isEmpty) throw Exception('PPTX encoding failed');
    await File(output).writeAsBytes(zipBytes);
    onProgress(0.9);
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