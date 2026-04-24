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

  /// Returns the output directory.
  /// Android: app-internal Documents folder (no permission needed, ever)
  /// iOS: app Documents directory
  static Future<Directory> getOutputDirectory() async {
  Directory? dir;

  if (Platform.isAndroid) {
    // getExternalStorageDirectory() → /storage/emulated/0/Android/data/com.example.pdf_reader/files
    // OpenFilex FileProvider can serve this path without extra config.
    dir = await getExternalStorageDirectory();
    if (dir != null) {
      final out = Directory(p.join(dir.path, 'PdfReaderPro'));
      if (!out.existsSync()) out.createSync(recursive: true);
      print('📂 Output dir (external app): ${out.path}');
      return out;
    }
  }

  // iOS or fallback
  final docs = await getApplicationDocumentsDirectory();
  final out = Directory(p.join(docs.path, 'PdfReaderPro'));
  if (!out.existsSync()) out.createSync(recursive: true);
  print('📂 Output dir (documents): ${out.path}');
  return out;
}

  /// Sanitize a filename so it is safe for Android FileProvider and URIs.
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
    // Add timestamp to avoid overwriting previous conversions
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(outDir.path, '${safeName}_$timestamp.${targetFormat.name}');
  }

  /// Scan a directory for supported files
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
      return SupportedFormat.values.firstWhere(
        (f) => f.name == ext || (ext == 'jpeg' && f == SupportedFormat.jpg),
      );
    } catch (_) {
      return null;
    }
  }
}