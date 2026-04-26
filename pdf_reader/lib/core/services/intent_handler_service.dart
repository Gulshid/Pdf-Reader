import 'dart:io';
import 'package:flutter/services.dart';

/// Holds both the local file path (for reading) and the
/// original display name (for showing to the user).
class ResolvedFile {
  const ResolvedFile({required this.path, required this.displayName});
  final String path;
  final String displayName;
}

class IntentHandlerService {
  static const _methodChannel = MethodChannel('pdf_reader/intent');
  static const _eventChannel  = EventChannel('pdf_reader/intent_event');

  /// Called once at startup — returns the file if the app was opened
  /// via a file (cold-start intent from WhatsApp, Gmail, Files, etc.).
  static Future<ResolvedFile?> getInitialFile() async {
    try {
      final uri = await _methodChannel.invokeMethod<String>('getInitialUri');
      if (uri == null || uri.isEmpty) return null;
      return await _resolveUri(uri);
    } on PlatformException catch (e) {
      debugPrintPlatformException(e, 'getInitialFilePath');
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of resolved files when the app is already running and receives
  /// a new file intent (e.g. user opens a second file from WhatsApp).
  static Stream<ResolvedFile?> get onNewFile {
    return _eventChannel
        .receiveBroadcastStream()
        .asyncMap((uri) async {
          if (uri == null) return null;
          return await _resolveUri(uri.toString());
        });
  }

  // ── Legacy path-only accessors (kept for backward compatibility) ──────────

  /// @deprecated Use [getInitialFile] instead.
  static Future<String?> getInitialFilePath() async {
    final f = await getInitialFile();
    return f?.path;
  }

  /// @deprecated Use [onNewFile] instead.
  static Stream<String?> get onNewFilePath =>
      onNewFile.map((f) => f?.path);

  // ── Internal ─────────────────────────────────────────────────────────────

  /// Resolves any URI scheme to a [ResolvedFile] the app can use.
  ///
  ///  file://…      → strip prefix, use filename from path as display name
  ///  content://…   → ask Android to copy to cache; Android now returns
  ///                  BOTH the cache path AND the original display name
  ///  /absolute     → return as-is, use filename from path
  static Future<ResolvedFile?> _resolveUri(String uri) async {
    try {
      // ── file:// ────────────────────────────────────────────────────────
      if (uri.startsWith('file://')) {
        final decoded = Uri.decodeComponent(uri.replaceFirst('file://', ''));
        final f = File(decoded);
        if (!f.existsSync()) return null;
        return ResolvedFile(
          path: f.path,
          displayName: f.path.split('/').last,
        );
      }

      // ── content:// ────────────────────────────────────────────────────
      // MainActivity.copyContentUriToCache() now returns a Map:
      //   { "path": "/data/.../cache/safe_name.docx",
      //     "displayName": "lecture 9_177.docx" }
      if (uri.startsWith('content://')) {
        final result = await _methodChannel
            .invokeMethod<Map>('resolveContentUri', uri);
        if (result == null) return null;

        final path = result['path'] as String?;
        final displayName = result['displayName'] as String?;

        if (path == null || path.isEmpty) return null;
        if (!File(path).existsSync()) return null;

        // Use the original display name if available; fall back to cache filename
        final name = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : path.split('/').last;

        return ResolvedFile(path: path, displayName: name);
      }

      // ── absolute path ─────────────────────────────────────────────────
      if (uri.startsWith('/')) {
        final f = File(uri);
        if (!f.existsSync()) return null;
        return ResolvedFile(
          path: f.path,
          displayName: f.path.split('/').last,
        );
      }

      return null;
    } on PlatformException catch (e) {
      debugPrintPlatformException(e, '_resolveUri($uri)');
      return null;
    } catch (_) {
      return null;
    }
  }

  static void debugPrintPlatformException(PlatformException e, String context) {
    assert(() {
      // ignore: avoid_print
      print('[IntentHandlerService] $context — '
          'code=${e.code} message=${e.message}');
      return true;
    }());
  }
}