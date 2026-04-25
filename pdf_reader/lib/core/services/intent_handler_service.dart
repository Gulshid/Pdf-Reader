import 'dart:io';
import 'package:flutter/services.dart';

class IntentHandlerService {
  static const _methodChannel = MethodChannel('pdf_reader/intent');
  static const _eventChannel  = EventChannel('pdf_reader/intent');

  /// Called once at startup — returns the file path if app was opened via a file.
  static Future<String?> getInitialFilePath() async {
    try {
      final uri = await _methodChannel.invokeMethod<String>('getInitialUri');
      if (uri == null || uri.isEmpty) return null;
      return await _resolveUri(uri);
    } catch (_) {
      return null;
    }
  }

  /// Stream of file paths when app is already running and receives a new intent.
  static Stream<String?> get onNewFilePath {
    return _eventChannel
        .receiveBroadcastStream()
        .asyncMap((uri) async {
          if (uri == null) return null;
          return await _resolveUri(uri.toString());
        });
  }

  static Future<String?> _resolveUri(String uri) async {
    try {
      if (uri.startsWith('file://')) {
        final path = uri.replaceFirst('file://', '');
        return File(path).existsSync() ? path : null;
      }

      if (uri.startsWith('content://')) {
        final path = await _methodChannel
            .invokeMethod<String>('resolveContentUri', uri);
        return path;
      }

      if (uri.startsWith('/') && File(uri).existsSync()) return uri;

      return null;
    } catch (_) {
      return null;
    }
  }
}
