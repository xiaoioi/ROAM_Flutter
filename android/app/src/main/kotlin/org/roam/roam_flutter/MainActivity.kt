package org.roam.roam_flutter

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "org.roam.roam_flutter/photo_picker"
    private val systemChannelName = "org.roam.roam_flutter/system"
    private var pendingResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Another pick is in progress", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        launchPhotoPicker()
                    }
                    "pickFile" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Another pick is in progress", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        launchFilePicker()
                    }
                    "openAppDetails" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 网页协议跳转 + 网页权限：与鸿蒙 EntryAbility 里的同名通道对齐。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openExternal" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrEmpty()) {
                            result.success("failed:empty url")
                        } else {
                            result.success(openExternal(url))
                        }
                    }
                    "ensurePermissions" -> {
                        val kinds = call.argument<List<String>>("kinds") ?: emptyList()
                        requestSystemPermissions(kinds, result)
                    }
                    "readClipboard" -> result.success(readClipboardText())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 用隐式 Intent 拉起第三方 App。
     *
     * 关键点：不能用 PackageManager.resolveActivity 预判（Android 11 起受
     * 包可见性限制，没在 <queries> 声明的一律查不到），直接 startActivity，
     * 捕 ActivityNotFoundException 即可。
     */
    private fun openExternal(url: String): String {
        return try {
            val intent: Intent
            var fallback: String? = null
            if (url.startsWith("intent:")) {
                intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                fallback = intent.getStringExtra("browser_fallback_url")
                intent.component = null
            } else {
                intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // 大多数客户端声明了 BROWSABLE，但个别只声明 DEFAULT，
            // 带上 BROWSABLE 反而匹配不到，所以失败后再去掉重试一次。
            intent.addCategory(Intent.CATEGORY_BROWSABLE)
            if (tryStart(intent)) return "opened"

            intent.removeCategory(Intent.CATEGORY_BROWSABLE)
            if (tryStart(intent)) return "opened"

            if (!fallback.isNullOrEmpty()) {
                "fallback:$fallback"
            } else {
                val store = playStoreUrlFor(url)
                if (store != null && tryStart(Intent(Intent.ACTION_VIEW, Uri.parse(store)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                ) {
                    "opened"
                } else {
                    "noHandler"
                }
            }
        } catch (e: Exception) {
            "failed:${e.message}"
        }
    }

    private fun tryStart(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    /** market:// 协议在没有应用市场的设备上退化成网页。 */
    private fun playStoreUrlFor(url: String): String? {
        if (!url.startsWith("market://")) return null
        val id = Uri.parse(url).getQueryParameter("id") ?: return null
        return "https://play.google.com/store/apps/details?id=$id"
    }

    private fun requestSystemPermissions(kinds: List<String>, result: MethodChannel.Result) {
        val wanted = ArrayList<String>()
        for (kind in kinds) {
            when (kind) {
                "camera" -> wanted.add(Manifest.permission.CAMERA)
                "microphone" -> wanted.add(Manifest.permission.RECORD_AUDIO)
                "location" -> {
                    wanted.add(Manifest.permission.ACCESS_FINE_LOCATION)
                    wanted.add(Manifest.permission.ACCESS_COARSE_LOCATION)
                }
            }
        }
        val missing = wanted.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("BUSY", "Another permission request is in progress", null)
            return
        }
        permissionResult = result
        requestPermissions(missing.toTypedArray(), REQUEST_PERMISSIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_PERMISSIONS) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        permissionResult?.success(granted)
        permissionResult = null
    }

    @Suppress("DEPRECATION")
    private fun readClipboardText(): String? {
        return try {
            val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = manager.primaryClip ?: return null
            if (clip.itemCount == 0) return null
            clip.getItemAt(0).coerceToText(this)?.toString()
        } catch (e: Exception) {
            null
        }
    }

    private fun launchPhotoPicker() {
        val intent = Intent(MediaStore.ACTION_PICK_IMAGES).apply {
            type = "image/*"
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_IMAGE)
        } catch (e: Exception) {
            // 旧系统不支持 ACTION_PICK_IMAGES 时降级到 GET_CONTENT
            try {
                val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                }
                startActivityForResult(fallback, REQUEST_PICK_IMAGE)
            } catch (e2: Exception) {
                pendingResult?.error("UNAVAILABLE", "No photo picker available", null)
                pendingResult = null
            }
        }
    }

    private fun launchFilePicker() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_FILE)
        } catch (e: Exception) {
            pendingResult?.error("UNAVAILABLE", "No file picker available", null)
            pendingResult = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_IMAGE && requestCode != REQUEST_PICK_FILE) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.success(null)
            pendingResult = null
            return
        }

        val uri: Uri? = data.data
        if (uri == null) {
            pendingResult?.success(null)
            pendingResult = null
            return
        }

        // 把用户选中的文件拷贝到应用私有目录，返回本地路径。
        // 壁纸必须用**唯一文件名**：以前固定叫 custom_wallpaper.jpg，
        // 第二次选图会覆盖同一路径，而 Flutter 的 Image 缓存以路径为键，
        // 界面继续命中旧解码结果，表现就是「设置一次后再也换不掉」。
        // 另外写到 filesDir 而不是 cacheDir——缓存目录会被系统回收，
        // 重启后壁纸路径就失效了。
        try {
            val localPath = if (requestCode == REQUEST_PICK_IMAGE) {
                copyUriToStore(uri, "wallpapers", "custom_wallpaper_${System.currentTimeMillis()}")
            } else {
                copyUriToStore(uri, "picked", "picked_${System.currentTimeMillis()}")
            }
            pendingResult?.success(localPath)
        } catch (e: Exception) {
            pendingResult?.error("COPY_FAILED", e.message, null)
        }
        pendingResult = null
    }

    private fun copyUriToStore(uri: Uri, subDir: String, fileName: String): String {
        val input = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Cannot open file stream")
        val dir = File(filesDir, subDir).apply { mkdirs() }
        // 只保留最新一张自定义壁纸，避免无限堆积。
        dir.listFiles()?.forEach { old ->
            if (old.isFile && old.name.startsWith("custom_wallpaper_")) {
                old.delete()
            }
        }
        val outFile = File(dir, fileName)
        FileOutputStream(outFile).use { output ->
            input.copyTo(output)
        }
        input.close()
        return outFile.absolutePath
    }

    companion object {
        private const val REQUEST_PICK_IMAGE = 0x524F
        private const val REQUEST_PICK_FILE = 0x5250
        private const val REQUEST_PERMISSIONS = 0x5251
    }
}
