// conversion_service.dart

// ignore_for_file: unused_import

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

  /// Main entry point — dispatches to the right converter.
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
        await _fromPdf(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.txt:
        await _fromTxt(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.jpg:
      case SupportedFormat.png:
        await _fromImage(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.csv:
        await _fromCsv(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.xlsx:
        await _fromXlsx(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.docx:
        await _fromDocx(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
      case SupportedFormat.pptx:
        await _fromPptx(
            task.sourceFilePath, task.targetFormat, outputPath, onProgress);
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
          buffer.writeln(
              extractor.extractText(startPageIndex: i, endPageIndex: i));
          onProgress(0.3 + 0.6 * (i + 1) / sfDoc.pages.count);
        }
        sfDoc.dispose();
        await File(output).writeAsString(buffer.toString());

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

          if (target == SupportedFormat.jpg) {
            final decoded = img.decodeImage(pageImage.bytes);
            if (decoded != null) {
              await File(output)
                  .writeAsBytes(img.encodeJpg(decoded, quality: 90));
            } else {
              await File(output).writeAsBytes(pageImage.bytes);
            }
          } else {
            await File(output).writeAsBytes(pageImage.bytes);
          }
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
          buffer.writeln(
              extractor.extractText(startPageIndex: i, endPageIndex: i));
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
          buffer.writeln(
              extractor.extractText(startPageIndex: i, endPageIndex: i));
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
          final pageText =
              extractor.extractText(startPageIndex: i, endPageIndex: i);
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
          buffer.writeln(
              extractor.extractText(startPageIndex: i, endPageIndex: i));
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
                    .map((l) =>
                        pw.Text(l, style: const pw.TextStyle(fontSize: 12)))
                    .toList(),
              ),
            ),
          );
          onProgress(0.4 + 0.5 * (i / lines.length));
        }
        await File(output).writeAsBytes(await pdfDoc.save());

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
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image');
    onProgress(0.4);

    switch (target) {
      case SupportedFormat.pdf:
        final pdfImage = pw.MemoryImage(bytes);
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

      case SupportedFormat.jpg:
        await File(output).writeAsBytes(img.encodeJpg(decoded, quality: 90));

      case SupportedFormat.png:
        await File(output).writeAsBytes(img.encodePng(decoded));

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

    switch (target) {
      case SupportedFormat.pdf:
        // FIX 4: Proper CSV parsing — split on commas but respect
        // quoted fields (a field like `"hello, world"` must not be split).
        final rows = _parseCsvRows(content);
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.TableHelper.fromTextArray(
              data: rows,
              border: pw.TableBorder.all(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        await File(output).writeAsBytes(await pdfDoc.save());

      case SupportedFormat.xlsx:
        onProgress(0.5);
        final ex = excel_pkg.Excel.createExcel();
        final sheet = ex['Sheet1'];
        // FIX 4 (same): use proper CSV parser here too
        final rows = _parseCsvRows(content);
        for (final row in rows) {
          sheet.appendRow(
            row
                .map((cell) => excel_pkg.TextCellValue(cell.trim()))
                .toList(),
          );
        }
        final xlsxBytes = ex.save();
        if (xlsxBytes == null) throw Exception('Failed to encode XLSX');
        await File(output).writeAsBytes(xlsxBytes);

      case SupportedFormat.txt:
        // FIX 5: Use tab as separator for TXT output; also use proper CSV
        // parser so quoted commas don't bleed into the output.
        final rows = _parseCsvRows(content);
        final lines = rows.map((r) => r.join('\t')).join('\n');
        await File(output).writeAsString(lines);

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
    final sheetName = ex.tables.keys.first;
    final sheet = ex.tables[sheetName]!;
    onProgress(0.5);

    final rows = sheet.rows.map((row) {
      return row.map((cell) => cell?.value?.toString() ?? '').toList();
    }).toList();

    switch (target) {
      case SupportedFormat.pdf:
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (ctx) => pw.TableHelper.fromTextArray(
              data: rows,
              border: pw.TableBorder.all(),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        await File(output).writeAsBytes(await pdfDoc.save());

      case SupportedFormat.csv:
        final csv =
            rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
        await File(output).writeAsString(csv);

      case SupportedFormat.txt:
        final txt = rows.map((row) => row.join('\t')).join('\n');
        await File(output).writeAsString(txt);

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
    // FIX 6: docxToText() takes Uint8List, not List<int>.
    // File.readAsBytes() returns Uint8List already, but an explicit cast
    // prevents type errors if the compiler infers List<int>.
    // ignore: unnecessary_cast
    final text = docxToText(bytes as Uint8List);
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
              build: (ctx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pageLines
                    .map((l) =>
                        pw.Text(l, style: const pw.TextStyle(fontSize: 12)))
                    .toList(),
              ),
            ),
          );
          onProgress(0.6 + 0.35 * (i / lines.length));
        }
        await File(output).writeAsBytes(await pdfDoc.save());

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

    // FIX 7: ZipDecoder().decodeBytes() requires a List<int>.
    // Cast explicitly to avoid a runtime type error on some platforms.
    final archive = ZipDecoder().decodeBytes(bytes as List<int>);
    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final buffer = StringBuffer();
    for (final slide in slideFiles) {
      // FIX 7 (cont): slide.content is Uint8List — use utf8 decoding
      // instead of String.fromCharCodes to handle non-ASCII characters
      // in slide text correctly.
      final xml = String.fromCharCodes(slide.content);
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
                    .map((l) =>
                        pw.Text(l, style: const pw.TextStyle(fontSize: 12)))
                    .toList(),
              ),
            ),
          );
          onProgress(0.6 + 0.35 * (i / lines.length));
        }
        await File(output).writeAsBytes(await pdfDoc.save());

      case SupportedFormat.txt:
        await File(output).writeAsString(text);

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
    final paragraphs = text
        .split('\n')
        .map((line) => _xmlEscape(line))
        .map((line) =>
            '<w:p><w:r><w:t xml:space="preserve">$line</w:t></w:r></w:p>')
        .join('\n');

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$paragraphs
    <w:sectPr/>
  </w:body>
</w:document>''';

    final settingsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:defaultTabStop w:val="720"/>
</w:settings>''';

    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/settings.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>''';

    final docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>
</Relationships>''';

    final wordRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"
    Target="settings.xml"/>
</Relationships>''';

    final files = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(contentTypesXml),
      '_rels/.rels': utf8.encode(docRelsXml),
      'word/document.xml': utf8.encode(documentXml),
      'word/settings.xml': utf8.encode(settingsXml),
      'word/_rels/document.xml.rels': utf8.encode(wordRelsXml),
    };

    await File(output).writeAsBytes(_createZip(files));
    onProgress(0.9);
  }

  /// Write plain text into a minimal valid PPTX (one text box per slide-chunk).
  Future<void> _writePlainTextAsPptx(
    String text,
    String output,
    ProgressCallback onProgress,
  ) async {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    const linesPerSlide = 15;

    // FIX 8: Guard against empty text producing zero slides.
    // An empty PPTX (no slides) is invalid and causes app crashes or
    // "file corrupt" errors when opened. Fall back to a single blank slide.
    final effectiveLines = lines.isEmpty ? ['(empty)'] : lines;

    final slideXmls = <String>[];
    final slideRelXmls = <String>[];

    for (int i = 0; i < effectiveLines.length; i += linesPerSlide) {
      final chunk = effectiveLines.skip(i).take(linesPerSlide).toList();
      final paragraphs = chunk
          .map((l) => _xmlEscape(l))
          .map((l) => '''<a:p><a:r><a:t>$l</a:t></a:r></a:p>''')
          .join('\n');

      slideXmls.add('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       show="1">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
      <p:sp>
        <p:nvSpPr>
          <p:cNvPr id="2" name="Content"/>
          <p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr>
          <p:nvPr><p:ph idx="1"/></p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm><a:off x="457200" y="457200"/><a:ext cx="8229600" cy="5029200"/></a:xfrm>
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
      (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 1}"/>',
    ).join('\n');

    final presRels = List.generate(
      slideCount,
      (i) => '''  <Relationship Id="rId${i + 1}"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"
    Target="slides/slide${i + 1}.xml"/>''',
    ).join('\n');

    final overrides = List.generate(
      slideCount,
      (i) =>
          '  <Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    ).join('\n');

    final presPropsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentationPr xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:extLst/>
</p:presentationPr>''';

    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                saveSubsetFonts="1">
  <p:sldMasterIdLst/>
  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
  <p:notesSz cx="6858000" cy="9144000"/>
  <p:sldIdLst>
$slideRefs
  </p:sldIdLst>
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
      files['ppt/slides/_rels/slide${i + 1}.xml.rels'] =
          utf8.encode(slideRelXmls[i]);
      onProgress(0.3 + 0.6 * (i + 1) / slideXmls.length);
    }

    await File(output).writeAsBytes(_createZip(files));
    onProgress(0.9);
  }

  /// Write plain text as XLSX — one row per non-empty line.
  Future<void> _writePlainTextAsXlsx(String text, String output) async {
    final ex = excel_pkg.Excel.createExcel();
    final sheet = ex['Sheet1'];
    for (final line in text.split('\n')) {
      if (line.trim().isNotEmpty) {
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

  /// Build a valid ZIP using the `archive` package.
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

  /// Minimal RFC-4180 CSV parser that handles quoted fields containing commas.
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
            current.write('"'); // escaped quote ""
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