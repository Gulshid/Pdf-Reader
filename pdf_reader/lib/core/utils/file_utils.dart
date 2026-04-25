import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../shared/models/pdf_file_model.dart';
import '../../shared/models/conversion_task_model.dart';

class FileUtils {
  const FileUtils._();

  static const _uuid = Uuid();

  static String generateId() => _uuid.v4();

  static Future<Directory> getOutputDirectory() async {
    Directory? dir;

    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
      if (dir != null) {
        final out = Directory(p.join(dir.path, 'PdfReaderPro'));
        if (!out.existsSync()) out.createSync(recursive: true);
        return out;
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final out = Directory(p.join(docs.path, 'PdfReaderPro'));
    if (!out.existsSync()) out.createSync(recursive: true);
    return out;
  }

  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r"""[#%&{}<>*?$!'"":@+`|=\\]"""), '_');
  }

  static Future<String> buildOutputPath(
    String sourceFilePath,
    SupportedFormat targetFormat,
  ) async {
    final outDir = await getOutputDirectory();
    final rawName = p.basenameWithoutExtension(sourceFilePath);
    final safeName = sanitizeFileName(rawName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(outDir.path, '${safeName}_$timestamp.${targetFormat.name}');
  }

  static Future<List<PdfFileModel>> scanDirectory(Directory dir) async {
    const supported = {
      '.pdf', '.docx', '.txt', '.jpg', '.jpeg',
      '.png', '.csv', '.xlsx', '.pptx',
    };
    final files = <PdfFileModel>[];

    if (!dir.existsSync()) return files;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (supported.contains(ext)) {
          files.add(PdfFileModel.fromFile(entity));
        }
      }
    }
    return files;
  }

  static SupportedFormat? detectFormat(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    try {
      return SupportedFormat.values.firstWhere((f) =>
        f.name == ext ||
        // jpeg is the same as jpg
        (ext == 'jpeg' && f == SupportedFormat.jpg)  ||
        // Legacy Office formats → map to their modern OOXML equivalent
        (ext == 'ppt'  && f == SupportedFormat.pptx) ||
        (ext == 'doc'  && f == SupportedFormat.docx) ||
        (ext == 'xls'  && f == SupportedFormat.xlsx),
      );
    } catch (_) {
      return null;
    }
  }
}