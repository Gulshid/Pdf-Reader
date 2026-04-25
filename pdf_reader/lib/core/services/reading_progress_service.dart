import 'package:hive_flutter/hive_flutter.dart';

/// Persists last-opened page and total page count per PDF file.
/// Key pattern: "progress_<fileId>"  →  "<currentPage>/<totalPages>"
class ReadingProgressService {
  static const _boxName = 'reading_progress';
  static Box<String>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  static Box<String> get _b {
    assert(_box != null, 'Call ReadingProgressService.init() first');
    return _box!;
  }

  static String _key(String fileId) => 'progress_$fileId';

  /// Save progress. [totalPages] is optional — kept from previous save if omitted.
  static void save(String fileId, int currentPage, {int? totalPages}) {
    final existing = get(fileId);
    final total = totalPages ?? existing?.totalPages ?? 0;
    _b.put(_key(fileId), '$currentPage/$total');
  }

  /// Returns null if no progress stored yet.
  static ReadingProgress? get(String fileId) {
    final raw = _b.get(_key(fileId));
    if (raw == null) return null;
    final parts = raw.split('/');
    if (parts.length != 2) return null;
    return ReadingProgress(
      currentPage: int.tryParse(parts[0]) ?? 0,
      totalPages: int.tryParse(parts[1]) ?? 0,
    );
  }

  static void delete(String fileId) => _b.delete(_key(fileId));
}

class ReadingProgress {
  const ReadingProgress({required this.currentPage, required this.totalPages});
  final int currentPage;
  final int totalPages;

  /// 0.0 – 1.0
  double get fraction =>
      (totalPages > 0) ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

  String get label => totalPages > 0 ? 'Page $currentPage / $totalPages' : '';
}
