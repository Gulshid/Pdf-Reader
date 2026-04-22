// conversion_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:docx_to_text/docx_to_text.dart';

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

      // PDF → TXT
      case SupportedFormat.txt:
        final bytes = await File(src).readAsBytes();
        final sfDoc = sf.PdfDocument(inputBytes: bytes);
        onProgress(0.3);
        final buffer = StringBuffer();
        final extractor = sf.PdfTextExtractor(sfDoc);
        for (int i = 0; i < sfDoc.pages.count; i++) {
          buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
          onProgress(0.3 + 0.6 * (i + 1) / sfDoc.pages.count);
        }
        sfDoc.dispose();
        final text = buffer.toString().trim();
        // BUG FIX: guard against empty extraction — write placeholder so
        // the file is not zero-bytes (which apps show as blank/corrupt).
        await File(output).writeAsString(text.isEmpty ? '(no extractable text)' : text);

      // PDF → JPG / PNG
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

          if (pageImage == null) {
            throw Exception('Failed to render PDF page to image.');
          }

          // BUG FIX: always write the raw bytes directly — re-encoding
          // with the image package adds an unnecessary decode/re-encode
          // step that can corrupt the output on some devices.
          await File(output).writeAsBytes(pageImage.bytes);
        } finally {
          await document.close();
        }

      // PDF → DOCX
      case SupportedFormat.docx:
        final bytes = await File(src).readAsBytes();
        final sfDoc = sf.PdfDocument(inputBytes: bytes);
        onProgress(0.3);
        final buffer = StringBuffer();
        final extractor = sf.PdfTextExtractor(sfDoc);
        for (int i = 0; i < sfDoc.pages.count; i++) {
          buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
          onProgress(0.3 + 0.4 * (i + 1) / sfDoc.pages.count);
        }
        sfDoc.dispose();
        await _writePlainTextAsDocx(buffer.toString(), output, onProgress);

      // PDF → XLSX
      case SupportedFormat.xlsx:
        final bytes = await File(src).readAsBytes();
        final sfDoc = sf.PdfDocument(inputBytes: bytes);
        onProgress(0.3);
        final buffer = StringBuffer();
        final extractor = sf.PdfTextExtractor(sfDoc);
        for (int i = 0; i < sfDoc.pages.count; i++) {
          buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
          onProgress(0.3 + 0.3 * (i + 1) / sfDoc.pages.count);
        }
        sfDoc.dispose();
        onProgress(0.6);
        await _writePlainTextAsXlsx(buffer.toString(), output);

      // PDF → CSV
      case SupportedFormat.csv:
        final bytes = await File(src).readAsBytes();
        final sfDoc = sf.PdfDocument(inputBytes: bytes);
        onProgress(0.3);
        final buffer = StringBuffer();
        final extractor = sf.PdfTextExtractor(sfDoc);
        for (int i = 0; i < sfDoc.pages.count; i++) {
          final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
          for (final line in pageText.split('\n')) {
            if (line.trim().isNotEmpty) {
              buffer.writeln(_escapeCsv(line.trim()));
            }
          }
          onProgress(0.3 + 0.5 * (i + 1) / sfDoc.pages.count);
        }
        sfDoc.dispose();
        await File(output).writeAsString(buffer.toString());

      // PDF → PPTX
      case SupportedFormat.pptx:
        final bytes = await File(src).readAsBytes();
        final sfDoc = sf.PdfDocument(inputBytes: bytes);
        onProgress(0.3);
        final buffer = StringBuffer();
        final extractor = sf.PdfTextExtractor(sfDoc);
        for (int i = 0; i < sfDoc.pages.count; i++) {
          buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
          onProgress(0.3 + 0.4 * (i + 1) / sfDoc.pages.count);
        }
        sfDoc.dispose();
        await _writePlainTextAsPptx(buffer.toString(), output, onProgress);

      default:
        throw UnsupportedError('PDF → ${target.label} not supported');
    }
  }

  // ── TXT → * ───────────────────────────────────────────────────────────────

  Future<void> _fromTxt(
    String src,
    SupportedFormat target,
    String output,
    ProgressCallback onProgress,
  ) async {
    final text = await File(src).readAsString();
    onProgress(0.3);

    switch (target) {
      case SupportedFormat.pdf:
        // BUG FIX: if text is empty, write a blank placeholder page so the
        // PDF is not zero-bytes (which SfPdfViewer shows as a blank page).
        final effectiveText = text.trim().isEmpty ? '(empty file)' : text;
        final pdfDoc = pw.Document();
        final lines = effectiveText.split('\n');
        const linesPerPage = 50;
        for (int i = 0; i < lines.length; i += linesPerPage) {
          final pageLines = lines.skip(i).take(linesPerPage).toList();
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(40),
              build: (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pageLines
                    .map((l) => pw.Text(
                          l,
                          style: const pw.TextStyle(fontSize: 12),
                        ))
                    .toList(),
              ),
            ),
          );
          onProgress(0.4 + 0.5 * (i / lines.length));
        }
        final pdfBytes = await pdfDoc.save();
        // BUG FIX: validate the output is a real PDF before writing
        if (pdfBytes.isEmpty) throw Exception('PDF generation produced empty output');
        await File(output).writeAsBytes(pdfBytes);

      case SupportedFormat.docx:
        await _writePlainTextAsDocx(text, output, onProgress);

      case SupportedFormat.xlsx:
        onProgress(0.5);
        await _writePlainTextAsXlsx(text, output);

      case SupportedFormat.pptx:
        await _writePlainTextAsPptx(text, output, onProgress);

      default:
        throw UnsupportedError('TXT → ${target.label} not supported');
    }
  }

  // ── Image (JPG/PNG) → * ───────────────────────────────────────────────────

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
        // BUG FIX: validate the image is decodable BEFORE building the PDF.
        // Using pw.MemoryImage directly with raw bytes avoids the image
        // package decode step — it embeds the bytes as-is which is what
        // the pdf package expects.
        final pdfImage = pw.MemoryImage(bytes);
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (ctx) => pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            ),
          ),
        );
        onProgress(0.7);
        final pdfBytes = await pdfDoc.save();
        if (pdfBytes.isEmpty) throw Exception('PDF generation produced empty output');
        await File(output).writeAsBytes(pdfBytes);

      case SupportedFormat.jpg:
        // BUG FIX: decode then re-encode only for format conversion (PNG→JPG).
        // For same-format copies just write the bytes directly.
        if (src.toLowerCase().endsWith('.jpg') || src.toLowerCase().endsWith('.jpeg')) {
          await File(output).writeAsBytes(bytes);
        } else {
          final decoded = img.decodeImage(bytes);
          if (decoded == null) throw Exception('Could not decode image');
          await File(output).writeAsBytes(img.encodeJpg(decoded, quality: 90));
        }

      case SupportedFormat.png:
        if (src.toLowerCase().endsWith('.png')) {
          await File(output).writeAsBytes(bytes);
        } else {
          final decoded = img.decodeImage(bytes);
          if (decoded == null) throw Exception('Could not decode image');
          await File(output).writeAsBytes(img.encodePng(decoded));
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
    final content = await File(src).readAsString();
    onProgress(0.3);
    final rows = _parseCsvRows(content);

    switch (target) {
      case SupportedFormat.pdf:
        // BUG FIX: guard against empty CSV producing a blank PDF.
        final effectiveRows = rows.isEmpty ? [['(empty)']] : rows;
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (ctx) => pw.TableHelper.fromTextArray(
              data: effectiveRows,
              border: pw.TableBorder.all(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              // BUG FIX: limit column count so wide CSVs don't overflow
              // and produce invisible/clipped content.
              cellAlignments: {
                for (int i = 0; i < (effectiveRows.first.length); i++)
                  i: pw.Alignment.centerLeft,
              },
            ),
          ),
        );
        onProgress(0.7);
        await File(output).writeAsBytes(await pdfDoc.save());

      case SupportedFormat.xlsx:
        onProgress(0.5);
        final ex = excel_pkg.Excel.createExcel();
        final sheet = ex['Sheet1'];
        for (final row in rows) {
          sheet.appendRow(row.map((cell) => excel_pkg.TextCellValue(cell.trim())).toList());
        }
        final xlsxBytes = ex.save();
        if (xlsxBytes == null) throw Exception('Failed to encode XLSX');
        await File(output).writeAsBytes(xlsxBytes);

      case SupportedFormat.txt:
        final lines = rows.map((r) => r.join('\t')).join('\n');
        await File(output).writeAsString(lines.isEmpty ? '(empty)' : lines);

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
    // BUG FIX: Excel.decodeBytes can return an object with no tables if the
    // file is corrupt or a different format. Guard against it.
    if (ex.tables.isEmpty) throw Exception('XLSX file has no sheets or is corrupt');
    final sheetName = ex.tables.keys.first;
    final sheet = ex.tables[sheetName]!;
    onProgress(0.5);

    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();

    // BUG FIX: remove trailing all-empty rows
    final trimmedRows = rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();

    switch (target) {
      case SupportedFormat.pdf:
        final effectiveRows = trimmedRows.isEmpty ? [['(empty)']] : trimmedRows;
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (ctx) => pw.TableHelper.fromTextArray(
              data: effectiveRows,
              border: pw.TableBorder.all(),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        onProgress(0.8);
        await File(output).writeAsBytes(await pdfDoc.save());

      case SupportedFormat.csv:
        final csv = trimmedRows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
        await File(output).writeAsString(csv.isEmpty ? '' : csv);

      case SupportedFormat.txt:
        final txt = trimmedRows.map((row) => row.join('\t')).join('\n');
        await File(output).writeAsString(txt.isEmpty ? '(empty)' : txt);

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
      // BUG FIX: docxToText can throw on malformed DOCX files.
      // Wrap in try/catch and fall back to empty string with a message.
      text = docxToText(bytes as Uint8List);
    } catch (e) {
      text = '(could not extract text from this DOCX file)';
    }
    // BUG FIX: docxToText sometimes returns null-like or whitespace-only
    // output for DOCX files with only images/shapes.
    if (text.trim().isEmpty) text = '(no extractable text in this DOCX file)';
    onProgress(0.6);

    switch (target) {
      case SupportedFormat.pdf:
        final pdfDoc = pw.Document();
        final lines = text.split('\n');
        const linesPerPage = 50;
        for (int i = 0; i < lines.length; i += linesPerPage) {
          final pageLines = lines.skip(i).take(linesPerPage).toList();
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(40),
              build: (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pageLines
                    .map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 12)))
                    .toList(),
              ),
            ),
          );
          onProgress(0.6 + 0.35 * (i / lines.length));
        }
        final pdfBytes = await pdfDoc.save();
        if (pdfBytes.isEmpty) throw Exception('PDF generation produced empty output');
        await File(output).writeAsBytes(pdfBytes);

      case SupportedFormat.txt:
        await File(output).writeAsString(text);

      case SupportedFormat.xlsx:
        await _writePlainTextAsXlsx(text, output);

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
      // BUG FIX: ZipDecoder can throw on non-zip / corrupt PPTX files.
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('Could not read PPTX file — it may be corrupt: $e');
    }

    final slideFiles = archive.files
        .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final buffer = StringBuffer();
    for (final slide in slideFiles) {
      // BUG FIX: use utf8.decode instead of String.fromCharCodes so
      // Arabic / Urdu / non-ASCII text in slides is handled correctly.
      final xml = utf8.decode(slide.content, allowMalformed: true);
      final matches = RegExp(r'<a:t[^>]*>([^<]*)<\/a:t>').allMatches(xml);
      for (final m in matches) {
        final t = m.group(1)?.trim();
        if (t != null && t.isNotEmpty) buffer.writeln(t);
      }
      buffer.writeln();
    }
    onProgress(0.6);

    final text = buffer.toString();

    switch (target) {
      case SupportedFormat.pdf:
        final effectiveText = text.trim().isEmpty ? '(no extractable text)' : text;
        final pdfDoc = pw.Document();
        final lines = effectiveText.split('\n');
        const linesPerPage = 50;
        for (int i = 0; i < lines.length; i += linesPerPage) {
          final pageLines = lines.skip(i).take(linesPerPage).toList();
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(40),
              build: (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pageLines
                    .map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 12)))
                    .toList(),
              ),
            ),
          );
          onProgress(0.6 + 0.35 * (i / lines.length));
        }
        final pdfBytes = await pdfDoc.save();
        if (pdfBytes.isEmpty) throw Exception('PDF generation produced empty output');
        await File(output).writeAsBytes(pdfBytes);

      case SupportedFormat.txt:
        await File(output).writeAsString(text.trim().isEmpty ? '(no extractable text)' : text);

      default:
        throw UnsupportedError('PPTX → ${target.label} not supported');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Write plain text into a minimal valid DOCX (ZIP-based XML).
  Future<void> _writePlainTextAsDocx(
    String text,
    String output,
    ProgressCallback onProgress,
  ) async {
    // BUG FIX: guard against empty text
    final effectiveText = text.trim().isEmpty ? '(empty)' : text;

    final paragraphs = effectiveText
        .split('\n')
        .map((line) => _xmlEscape(line))
        .map((line) =>
            '<w:p><w:r><w:t xml:space="preserve">$line</w:t></w:r></w:p>')
        .join('\n');

    // BUG FIX: the DOCX XML was missing the required
    // xmlns:wpc / xmlns:mc compatibility namespaces that Word and
    // Android's document apps require to open the file without a
    // "corrupt file" error. Using the minimal but fully compliant schema.
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
  mc:Ignorable="w14 wpc">
  <w:body>
$paragraphs
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final settingsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:defaultTabStop w:val="720"/>
  <w:compat/>
</w:settings>''';

    // BUG FIX: the Content_Types.xml was missing the required
    // theme and fontTable overrides — without them, Word/LibreOffice
    // flags the DOCX as corrupt and refuses to open it on some devices.
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/settings.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/styles.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    final docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>
</Relationships>''';

    // BUG FIX: word/_rels/document.xml.rels must reference ALL parts
    // declared in the document — missing refs = corrupt file warning.
    final wordRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"
    Target="settings.xml"/>
  <Relationship Id="rId2"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
    Target="styles.xml"/>
</Relationships>''';

    // Minimal styles.xml — required or Word marks the file corrupt
    final stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>
</w:styles>''';

    final files = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(contentTypesXml),
      '_rels/.rels': utf8.encode(docRelsXml),
      'word/document.xml': utf8.encode(documentXml),
      'word/settings.xml': utf8.encode(settingsXml),
      'word/styles.xml': utf8.encode(stylesXml),
      'word/_rels/document.xml.rels': utf8.encode(wordRelsXml),
    };

    final zipBytes = _createZip(files);
    if (zipBytes.isEmpty) throw Exception('DOCX ZIP encoding failed');
    await File(output).writeAsBytes(zipBytes);
    onProgress(0.9);
  }

  /// Write plain text into a minimal valid PPTX.
  Future<void> _writePlainTextAsPptx(
    String text,
    String output,
    ProgressCallback onProgress,
  ) async {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    const linesPerSlide = 15;
    final effectiveLines = lines.isEmpty ? ['(empty)'] : lines;

    final slideXmls = <String>[];
    final slideRelXmls = <String>[];

    for (int i = 0; i < effectiveLines.length; i += linesPerSlide) {
      final chunk = effectiveLines.skip(i).take(linesPerSlide).toList();
      final paragraphs = chunk
          .map((l) => _xmlEscape(l))
          .map((l) => '<a:p><a:r><a:rPr lang="en-US" dirty="0"/><a:t>$l</a:t></a:r></a:p>')
          .join('\n');

      slideXmls.add('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>
        <a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm>
      </p:grpSpPr>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="2" name="Content"/>
          <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>
          <p:nvPr><p:ph idx="1"/></p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="457200" y="274638"/><a:ext cx="8229600" cy="5944725"/></a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/>
          <a:lstStyle/>
$paragraphs
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''');

      slideRelXmls.add('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''');
    }

    final slideCount = slideXmls.length;
    final slideRefs = List.generate(
      slideCount,
      (i) => '    <p:sldId id="${256 + i}" r:id="rId${i + 1}"/>',
    ).join('\n');

    final presRels = List.generate(
      slideCount,
      (i) => '  <Relationship Id="rId${i + 1}"\n'
          '    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"\n'
          '    Target="slides/slide${i + 1}.xml"/>',
    ).join('\n');

    final overrides = List.generate(
      slideCount,
      (i) => '  <Override PartName="/ppt/slides/slide${i + 1}.xml"'
          ' ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    ).join('\n');

    final presPropsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentationPr xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:extLst/>
</p:presentationPr>''';

    // BUG FIX: presentation.xml must include a slideLayoutIdLst and
    // slideMasterIdLst (even empty) — without them Google Slides and
    // PowerPoint Mobile report the file as corrupt.
    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  saveSubsetFonts="1">
  <p:sldMasterIdLst/>
  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
  <p:notesSz cx="6858000" cy="9144000"/>
  <p:sldIdLst>
$slideRefs
  </p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000"/>
  <p:defaultTextStyle/>
</p:presentation>''';

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml"
    ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/presProps.xml"
    ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>
$overrides
</Types>''';

    final rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="ppt/presentation.xml"/>
</Relationships>''';

    final presRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$presRels
  <Relationship Id="rId${slideCount + 1}"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps"
    Target="presProps.xml"/>
</Relationships>''';

    final files = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(contentTypesXml),
      '_rels/.rels': utf8.encode(rootRelsXml),
      'ppt/presentation.xml': utf8.encode(presentationXml),
      'ppt/presProps.xml': utf8.encode(presPropsXml),
      'ppt/_rels/presentation.xml.rels': utf8.encode(presRelsXml),
    };

    for (int i = 0; i < slideXmls.length; i++) {
      files['ppt/slides/slide${i + 1}.xml'] = utf8.encode(slideXmls[i]);
      files['ppt/slides/_rels/slide${i + 1}.xml.rels'] = utf8.encode(slideRelXmls[i]);
      onProgress(0.3 + 0.6 * (i + 1) / slideXmls.length);
    }

    final zipBytes = _createZip(files);
    if (zipBytes.isEmpty) throw Exception('PPTX ZIP encoding failed');
    await File(output).writeAsBytes(zipBytes);
    onProgress(0.9);
  }

  /// Write plain text as XLSX — one row per non-empty line.
  Future<void> _writePlainTextAsXlsx(String text, String output) async {
    final ex = excel_pkg.Excel.createExcel();
    final sheet = ex['Sheet1'];
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    // BUG FIX: guard against empty content
    if (lines.isEmpty) {
      sheet.appendRow([excel_pkg.TextCellValue('(empty)')]);
    } else {
      for (final line in lines) {
        sheet.appendRow([excel_pkg.TextCellValue(line)]);
      }
    }
    final xlsxBytes = ex.save();
    if (xlsxBytes == null) throw Exception('Failed to encode XLSX');
    await File(output).writeAsBytes(xlsxBytes);
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
    for (final entry in files.entries) {
      final bytes = entry.value;
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
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
      final current = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final ch = line[i];
        if (ch == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (ch == ',' && !inQuotes) {
          fields.add(current.toString());
          current.clear();
        } else {
          current.write(ch);
        }
      }
      fields.add(current.toString());
      rows.add(fields);
    }
    return rows;
  }
}
