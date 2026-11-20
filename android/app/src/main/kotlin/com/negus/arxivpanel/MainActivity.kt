package com.negus.arxivpanel

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// In-app update installer (sideloaded APK, no Play Store, no browser).
///
/// Dart calls "downloadAndInstall" on the "arxiv/update" channel with the
/// APK url + version. The download runs in Android's DownloadManager, so
/// its progress shows in the phone's notification shade while the user
/// keeps using the app. When the download finishes, the receiver below
/// launches the system installer for the downloaded APK; Android installs
/// it over the current app (same package + signing key), keeping login
/// and data. If the app was closed mid-download, tapping the finished
/// DownloadManager notification opens the APK the same way.
class MainActivity : FlutterActivity() {
    private var downloadReceiver: BroadcastReceiver? = null
    private var pendingDownloadId: Long = -1L
    private var pendingFileName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "arxiv/update")
            .setMethodCallHandler { call, result ->
                if (call.method == "downloadAndInstall") {
                    val url = call.argument<String>("url")
                    val version = call.argument<String>("version") ?: ""
                    if (url.isNullOrBlank()) {
                        result.success("failed")
                    } else {
                        result.success(downloadAndInstall(url, version))
                    }
                } else {
                    result.notImplemented()
                }
            }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
                val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                if (id != pendingDownloadId) return
                pendingDownloadId = -1L
                val fileName = pendingFileName
                pendingFileName = null
                if (fileName != null && isDownloadSuccessful(context, id)) {
                    installApk(context, fileName)
                }
            }
        }
        downloadReceiver = receiver
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            downloadReceiver?.let { unregisterReceiver(it) }
        } catch (_: IllegalArgumentException) {
            // Receiver was never registered; nothing to unregister.
        }
        downloadReceiver = null
        super.onDestroy()
    }

    /// Starts the DownloadManager download. Returns one of the result codes
    /// the Dart side (AppUpdater) understands: "started",
    /// "already_downloading", "needs_unknown_sources", or "failed".
    private fun downloadAndInstall(url: String, version: String): String {
        if (pendingDownloadId != -1L) return "already_downloading"
        // Android 8+: installing an APK from the app needs the user to allow
        // "Install unknown apps" for Arxiv once. Send them to that switch;
        // they tap Update again afterwards and the download starts.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            startActivity(settingsIntent)
            return "needs_unknown_sources"
        }
        val safeVersion = version.filter { it.isLetterOrDigit() || it == '.' || it == '-' }
        val fileName = if (safeVersion.isEmpty()) "arxiv-update.apk" else "arxiv-$safeVersion.apk"
        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle("Arxiv update")
            setDescription("Downloading version $version")
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            setMimeType("application/vnd.android.package-archive")
            setDestinationInExternalFilesDir(
                this@MainActivity,
                Environment.DIRECTORY_DOWNLOADS,
                fileName,
            )
        }
        return try {
            val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            pendingFileName = fileName
            pendingDownloadId = manager.enqueue(request)
            "started"
        } catch (_: Exception) {
            pendingDownloadId = -1L
            pendingFileName = null
            "failed"
        }
    }

    private fun isDownloadSuccessful(context: Context, id: Long): Boolean {
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor: Cursor? = manager.query(DownloadManager.Query().setFilterById(id))
        cursor?.use {
            if (it.moveToFirst()) {
                val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                return status == DownloadManager.STATUS_SUCCESSFUL
            }
        }
        return false
    }

    private fun installApk(context: Context, fileName: String) {
        val downloadsDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: return
        val file = File(downloadsDir, fileName)
        if (!file.exists()) return
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // No installer could handle the APK (should not happen on a
            // phone); the finished download stays in the notification,
            // where tapping it opens the file.
        }
    }
}
