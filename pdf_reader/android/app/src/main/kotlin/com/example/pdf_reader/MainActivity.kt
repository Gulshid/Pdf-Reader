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

                    // FIX: Now returns a Map { "path": String, "displayName": String }
                    // instead of just a plain String path.
                    // This lets Flutter show the ORIGINAL file name (e.g. "lecture 9.xlsx")
                    // even though the cached file is named "DOC_20260426_WA0001.xlsx".
                    "resolveContentUri" -> {
                        val uriStr = call.arguments as? String
                        if (uriStr == null) {
                            result.error("BAD_ARGS", "Expected a URI string", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val resolved = copyContentUriToCache(Uri.parse(uriStr))
                            // Return map with both the cache path AND the original display name
                            result.success(mapOf(
                                "path"        to resolved.first,
                                "displayName" to resolved.second
                            ))
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
            "application/msword"                     -> "doc"
            "application/vnd.ms-excel"               -> "xls"
            "application/vnd.ms-powerpoint"          -> "ppt"
            "application/pdf"                        -> "pdf"
            "text/plain"                             -> "txt"
            "text/csv", "text/comma-separated-values" -> "csv"
            "image/jpeg"                             -> "jpg"
            "image/png"                              -> "png"
            else -> MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        }
    }

    /**
     * Copies a content:// URI to cache.
     * Returns a Pair of (absoluteCachePath, originalDisplayName).
     *
     * The cache path is used to READ the file.
     * The displayName is the ORIGINAL name (e.g. "lecture 9_177.xlsx") which
     * Flutter uses for display — so the user never sees "DOC-20260426-WA0001".
     */
    private fun copyContentUriToCache(uri: Uri): Pair<String, String> {
        val cr: ContentResolver = contentResolver

        // Step 1: Get the original display name from the content resolver
        var originalDisplayName = ""
        cr.query(uri, null, null, null, null)?.use { cursor ->
            val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIdx >= 0 && cursor.moveToFirst()) {
                originalDisplayName = cursor.getString(nameIdx) ?: ""
            }
        }

        // Step 2: Get MIME type — always correct even when the name is wrong
        val mimeType: String? = cr.getType(uri)

        // Step 3: Determine the correct extension from the display name or MIME type
        val lastDot = originalDisplayName.lastIndexOf('.')
        val hasExtension = lastDot >= 0 && lastDot < originalDisplayName.length - 1

        val baseName: String
        val extension: String

        if (hasExtension) {
            baseName = originalDisplayName.substring(0, lastDot)
            extension = originalDisplayName.substring(lastDot + 1)
        } else {
            // WhatsApp strips extension — recover from MIME type
            baseName = if (lastDot >= 0) originalDisplayName.substring(0, lastDot)
                       else originalDisplayName.ifEmpty { "shared_file" }
            extension = extensionForMimeType(mimeType) ?: "bin"
        }

        // Step 4: Build the FINAL display name with guaranteed correct extension
        // This is what Flutter will show the user.
        val finalDisplayName = if (hasExtension) originalDisplayName
                               else "$baseName.$extension"

        // Step 5: Sanitise for the filesystem (cache file name)
        val safeBase = baseName.replace(Regex("[^a-zA-Z0-9._\\-]"), "_")
        val cacheFileName = "$safeBase.$extension"

        // Step 6: Copy to cache
        val outFile = File(cacheDir, cacheFileName)
        cr.openInputStream(uri)?.use { input ->
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        } ?: throw Exception("Cannot open input stream for URI: $uri")

        return Pair(outFile.absolutePath, finalDisplayName)
    }
}