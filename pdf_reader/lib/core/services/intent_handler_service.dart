import 'dart:io';
import 'package:flutter/services.dart';

class IntentHandlerService {
  static const _methodChannel = MethodChannel('pdf_reader/intent');
  static const _eventChannel  = EventChannel('pdf_reader/intent_event');

  /// Called once at startup — returns the file path if the app was opened
  /// via a file (cold-start intent from WhatsApp, Gmail, Files, etc.).
  static Future<String?> getInitialFilePath() async {
    try {
      final uri = await _methodChannel.invokeMethod<String>('getInitialUri');
      if (uri == null || uri.isEmpty) return null;
      return await _resolveUri(uri);
    } on PlatformException catch (e) {
      // Channel not implemented on this platform (e.g. desktop/web)
      debugPrintPlatformException(e, 'getInitialFilePath');
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream of file paths when the app is already running and receives a
  /// new file intent (e.g. user opens a second file from WhatsApp).
  static Stream<String?> get onNewFilePath {
    return _eventChannel
        .receiveBroadcastStream()
        .asyncMap((uri) async {
          if (uri == null) return null;
          return await _resolveUri(uri.toString());
        });
  }

  /// Resolves any URI scheme to an absolute file path the app can read.
  ///
  ///  file://…          → strip prefix, return path directly
  ///  content://…       → ask Android to copy to cache, return cache path
  ///  /absolute/path    → return as-is if the file exists
  static Future<String?> _resolveUri(String uri) async {
    try {
      // ── file:// ──────────────────────────────────────────────────────────
      if (uri.startsWith('file://')) {
        // file:// URIs are sometimes percent-encoded
        final decoded = Uri.decodeComponent(uri.replaceFirst('file://', ''));
        final f = File(decoded);
        return f.existsSync() ? f.path : null;
      }

      // ── content:// ───────────────────────────────────────────────────────
      // Android content URIs cannot be read as files directly.
      // MainActivity.copyContentUriToCache() copies the stream to the
      // app cache and returns the real path.
      if (uri.startsWith('content://')) {
        final path = await _methodChannel
            .invokeMethod<String>('resolveContentUri', uri);
        if (path == null || path.isEmpty) return null;
        return File(path).existsSync() ? path : null;
      }

      // ── absolute path ────────────────────────────────────────────────────
      if (uri.startsWith('/')) {
        final f = File(uri);
        return f.existsSync() ? f.path : null;
      }

      return null;
    } on PlatformException catch (e) {
      debugPrintPlatformException(e, '_resolveUri($uri)');
      return null;
    } catch (_) {
      return null;
    }
  }

  // ignore: avoid_print
  static void debugPrintPlatformException(PlatformException e, String context) {
    assert(() {
      // ignore: avoid_print
      print('[IntentHandlerService] $context — '
          'code=${e.code} message=${e.message}');
      return true;
    }());
  }
}
