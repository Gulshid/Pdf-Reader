package com.example.pdf_reader

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "pdf_reader/intent"
    private var pendingUri: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Store URI from launch intent before Flutter is ready
        pendingUri = extractUri(intent)

        // Method channel — Flutter calls this to get the launch URI
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialUri" -> {
                        result.success(pendingUri)
                        pendingUri = null
                    }
                    "resolveContentUri" -> {
                        val uri = call.arguments as? String
                        if (uri != null) {
                            result.success(copyContentToCache(Uri.parse(uri)))
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel — fires when app is already running and gets a new intent
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val uri = extractUri(intent) ?: return
        // Copy content:// to cache immediately so Flutter can use it
        val path = if (uri.startsWith("content://")) {
            copyContentToCache(Uri.parse(uri))
        } else {
            uri
        }
        eventSink?.success(path)
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun extractUri(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return null
        return intent.data?.toString()
            ?: (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.toString()
    }

    /** Copies a content:// URI into the app cache and returns the file path. */
    private fun copyContentToCache(uri: Uri): String? {
        return try {
            val resolver = contentResolver
            val cursor = resolver.query(uri, null, null, null, null)
            var fileName = "imported_file"
            cursor?.use {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (it.moveToFirst() && nameIndex >= 0) {
                    fileName = it.getString(nameIndex)
                }
            }
            val cacheFile = File(cacheDir, fileName)
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(cacheFile).use { output ->
                    input.copyTo(output)
                }
            }
            cacheFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}