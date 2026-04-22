// file_utils.dart

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

  /// Returns the downloads/documents directory
  static Future<Directory> getOutputDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/PdfReaderPro');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'PdfReaderPro'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> buildOutputPath(
    String sourceFilePath,
    SupportedFormat targetFormat,
  ) async {
    final outDir = await getOutputDirectory();
    final baseName = p.basenameWithoutExtension(sourceFilePath);
    return p.join(outDir.path, '$baseName.${targetFormat.name}');
  }

  /// Scan a directory for supported files
  static Future<List<PdfFileModel>> scanDirectory(Directory dir) async {
    const supported = {
      '.pdf', '.docx', '.txt', '.jpg', '.jpeg',
      '.png', '.csv', '.xlsx', '.pptx', // ✅ added pptx
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