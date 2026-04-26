import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

enum FileType { pdf, txt, csv, xlsx, docx, pptx, image, unknown }

class PdfFileModel extends Equatable {
  const PdfFileModel({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
    this.pageCount,
    this.thumbnail,
    this.isBookmarked = false,
    this.lastOpenedPage = 0,
  });

  final String id;
  final String name;
  final String path;
  final int size; // bytes
  final DateTime lastModified;
  final int? pageCount;
  final String? thumbnail;
  final bool isBookmarked;
  final int lastOpenedPage;

  // ── Computed getters ──────────────────────────────────────────────────────

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get dateFormatted => DateFormat('MMM dd, yyyy').format(lastModified);

  String get extension => name.split('.').last.toUpperCase();

  File get file => File(path);

  /// Detects the file type from the file extension.
  /// Used by the router to decide whether to open PdfViewerScreen
  /// or ConverterScreen when a file is received from an external app.
  FileType get fileType {
    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.pdf'                      => FileType.pdf,
      '.txt'                      => FileType.txt,
      '.csv'                      => FileType.csv,
      '.xlsx'                     => FileType.xlsx,
      '.docx'                     => FileType.docx,
      '.pptx'                     => FileType.pptx,
      '.jpg' || '.jpeg' || '.png' => FileType.image,
      _                           => FileType.unknown,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  PdfFileModel copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    DateTime? lastModified,
    int? pageCount,
    String? thumbnail,
    bool? isBookmarked,
    int? lastOpenedPage,
  }) {
    return PdfFileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      pageCount: pageCount ?? this.pageCount,
      thumbnail: thumbnail ?? this.thumbnail,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastOpenedPage: lastOpenedPage ?? this.lastOpenedPage,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'size': size,
        'lastModified': lastModified.toIso8601String(),
        'pageCount': pageCount,
        'thumbnail': thumbnail,
        'isBookmarked': isBookmarked,
        'lastOpenedPage': lastOpenedPage,
      };

  factory PdfFileModel.fromJson(Map<String, dynamic> json) => PdfFileModel(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        size: json['size'] as int,
        lastModified: DateTime.parse(json['lastModified'] as String),
        pageCount: json['pageCount'] as int?,
        thumbnail: json['thumbnail'] as String?,
        isBookmarked: json['isBookmarked'] as bool? ?? false,
        lastOpenedPage: json['lastOpenedPage'] as int? ?? 0,
      );

  /// Creates a model from a [File].
  ///
  /// [displayName] — pass the original filename when the file was received
  /// from an external app (e.g. WhatsApp), where the cached copy has an
  /// auto-generated name like "DOC_20260426_WA0001.docx".
  /// If omitted, the name is taken from the file path as before.
  factory PdfFileModel.fromFile(File file, {String? displayName}) => PdfFileModel(
        id: file.path.hashCode.toString(),
        name: displayName ?? file.path.split('/').last,
        path: file.path,
        size: file.lengthSync(),
        lastModified: file.lastModifiedSync(),
      );

  // ── Equatable ─────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [id, path, isBookmarked, lastOpenedPage];
}