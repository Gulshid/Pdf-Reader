package com.example.pdf_reader

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "pdf_reader/intent"
    private val EVENT_CHANNEL  = "pdf_reader/intent_event"

    // Holds the URI string from the cold-start intent
    private var initialUri: String? = null

    // EventChannel sink — set when Flutter starts listening
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture the URI that launched the app (cold start)
        initialUri = extractUri(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App already running — forward to Flutter via EventChannel
        val uri = extractUri(intent) ?: return
        eventSink?.success(uri)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── MethodChannel ────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getInitialUri" -> {
                        result.success(initialUri)
                        initialUri = null   // consume once
                    }

                    "resolveContentUri" -> {
                        val uriStr = call.arguments as? String
                        if (uriStr == null) {
                            result.error("BAD_ARGS", "Expected a URI string", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val resolved = copyContentUriToCache(Uri.parse(uriStr))
                            result.success(resolved)
                        } catch (e: Exception) {
                            result.error("RESOLVE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ── EventChannel ─────────────────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Extracts a URI string from any share / view intent. */
    private fun extractUri(intent: Intent?): String? {
        intent ?: return null
        if (intent.action != Intent.ACTION_VIEW &&
            intent.action != Intent.ACTION_SEND) return null

        val uri: Uri? = if (intent.action == Intent.ACTION_SEND) {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        } else {
            intent.data
        }

        return uri?.toString()
    }

    /**
     * Copies a content:// URI to the app's cache directory and returns
     * the absolute file path.  This is needed because most file pickers
     * and share-sheets give us a content URI, not a direct file path.
     */
    private fun copyContentUriToCache(uri: Uri): String {
        val cr: ContentResolver = contentResolver

        // Try to get the real file name from the URI
        var fileName = "shared_file"
        cr.query(uri, null, null, null, null)?.use { cursor ->
            val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIdx >= 0 && cursor.moveToFirst()) {
                fileName = cursor.getString(nameIdx) ?: fileName
            }
        }

        // Sanitise the name
        fileName = fileName.replace(Regex("[^a-zA-Z0-9._\\-]"), "_")

        val outFile = File(cacheDir, fileName)
        cr.openInputStream(uri)?.use { input ->
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw Exception("Cannot open input stream for URI: $uri")

        return outFile.absolutePath
    }
}