package com.example.pdf_reader

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "pdf_reader/intent"
    private val EVENT_CHANNEL  = "pdf_reader/intent_event"

    private var initialUri: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialUri = extractUri(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val uri = extractUri(intent) ?: return
        eventSink?.success(uri)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialUri" -> {
                        result.success(initialUri)
                        initialUri = null
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
     * Maps a MIME type to the correct file extension.
     * MimeTypeMap misses many common Office types, so we handle them explicitly.
     */
    private fun extensionForMimeType(mimeType: String?): String? {
        if (mimeType == null) return null
        return when (mimeType) {
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"   -> "docx"
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"         -> "xlsx"
            "application/vnd.openxmlformats-officedocument.presentationml.presentation" -> "pptx"
            "application/msword"        -> "doc"
            "application/vnd.ms-excel"  -> "xls"
            "application/vnd.ms-powerpoint" -> "ppt"
            "application/pdf"           -> "pdf"
            "text/plain"                -> "txt"
            "text/csv", "text/comma-separated-values" -> "csv"
            "image/jpeg"                -> "jpg"
            "image/png"                 -> "png"
            else -> MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        }
    }

    /**
     * Copies a content:// URI to cache and returns the absolute path.
     *
     * FIX: WhatsApp strips extensions from shared files (e.g. sends
     * "DOC-20260426-WA0002" instead of "DOC-20260426-WA0002.docx").
     * We recover the correct extension from the MIME type reported by
     * the content resolver, which is always accurate even when the
     * display name is wrong.
     */
    private fun copyContentUriToCache(uri: Uri): String {
        val cr: ContentResolver = contentResolver

        var rawName = "shared_file"
        cr.query(uri, null, null, null, null)?.use { cursor ->
            val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIdx >= 0 && cursor.moveToFirst()) {
                rawName = cursor.getString(nameIdx) ?: rawName
            }
        }

        // Get MIME type — this is always correct even when the name is wrong
        val mimeType: String? = cr.getType(uri)

        // Split name into base and extension
        val lastDot = rawName.lastIndexOf('.')
        // hasExtension = dot exists AND there are characters after it
        val hasExtension = lastDot >= 0 && lastDot < rawName.length - 1

        val baseName: String
        val extension: String

        if (hasExtension) {
            // Trust the declared extension (e.g. "lecture_9.xlsx" -> ext = "xlsx")
            baseName = rawName.substring(0, lastDot)
            extension = rawName.substring(lastDot + 1)
        } else {
            // No extension or trailing dot (e.g. "DOC-20260426-WA0002" or "DOC-20260426-WA0002.")
            // Recover from MIME type
            baseName = if (lastDot >= 0) rawName.substring(0, lastDot) else rawName
            extension = extensionForMimeType(mimeType) ?: "bin"
        }

        // Sanitise the base name only — keep the extension clean
        val safeBase = baseName.replace(Regex("[^a-zA-Z0-9._\\-]"), "_")
        val fileName = "$safeBase.$extension"

        val outFile = File(cacheDir, fileName)
        cr.openInputStream(uri)?.use { input ->
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw Exception("Cannot open input stream for URI: $uri")

        return outFile.absolutePath
    }
}