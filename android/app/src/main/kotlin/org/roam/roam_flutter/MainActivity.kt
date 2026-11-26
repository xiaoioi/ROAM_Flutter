package org.roam.roam_flutter

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "org.roam.roam_flutter/photo_picker"
    private val systemChannelName = "org.roam.roam_flutter/system"
    private val snapshotChannelName = "org.roam.roam_flutter/page_snapshot"
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

        // 网页预览图：预测式返回时拿它当「上一页」的背景。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, snapshotChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capture" -> {
                        val x = call.argument<Int>("x") ?: 0
                        val y = call.argument<Int>("y") ?: 0
                        val w = call.argument<Int>("width") ?: 0
                        val h = call.argument<Int>("height") ?: 0
                        val target = call.argument<Int>("targetWidth") ?: 480
                        capturePageSnapshot(x, y, w, h, target) { bytes ->
                            runOnUiThread { result.success(bytes) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------------------------------ 网页预览图

    /**
     * 抓一块窗口区域，缩到 [targetWidth] 宽、压成 JPEG 返回。
     *
     * WebView 在 Flutter 里是 platform view，Dart 侧的 `toImage()` 拿不到它的
     * 内容，只能在这里抓。优先 [PixelCopy]（读的是窗口合成后的真实像素），
     * 拿不到再退到「遍历视图树找 WebView，把它 draw 进一张缩小的 Bitmap」。
     */
    private fun capturePageSnapshot(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        targetWidth: Int,
        done: (ByteArray?) -> Unit,
    ) {
        if (width <= 0 || height <= 0) {
            done(null)
            return
        }
        val outWidth = targetWidth.coerceIn(160, 720)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            copyWindowRegion(x, y, width, height, outWidth) { bytes ->
                if (bytes != null) done(bytes) else done(drawWebView(outWidth))
            }
        } else {
            done(drawWebView(outWidth))
        }
    }

    private fun copyWindowRegion(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        outWidth: Int,
        done: (ByteArray?) -> Unit,
    ) {
        val decor = window?.decorView
        val flutterView = decor?.let { findFlutterView(it) }
        if (decor == null || flutterView == null) {
            done(null)
            return
        }
        // Flutter 的 global 坐标以 FlutterView 左上角为原点，PixelCopy 要的是
        // 窗口坐标，这里补上 FlutterView 在窗口里的偏移。
        val location = IntArray(2)
        flutterView.getLocationInWindow(location)
        val left = (location[0] + x).coerceAtLeast(0)
        val top = (location[1] + y).coerceAtLeast(0)
        val right = (location[0] + x + width).coerceAtMost(decor.width)
        val bottom = (location[1] + y + height).coerceAtMost(decor.height)
        if (right - left < 16 || bottom - top < 16) {
            done(null)
            return
        }

        val src = Rect(left, top, right, bottom)
        val bitmap = try {
            Bitmap.createBitmap(src.width(), src.height(), Bitmap.Config.ARGB_8888)
        } catch (e: Throwable) {
            done(null)
            return
        }
        try {
            PixelCopy.request(
                window,
                src,
                bitmap,
                { copyResult ->
                    if (copyResult == PixelCopy.SUCCESS) {
                        done(compressSnapshot(bitmap, outWidth))
                    } else {
                        done(null)
                    }
                },
                Handler(Looper.getMainLooper()),
            )
        } catch (e: Throwable) {
            done(null)
        }
    }

    private fun drawWebView(outWidth: Int): ByteArray? {
        val webView = findVisibleWebView() ?: return null
        val sourceWidth = webView.width
        val sourceHeight = webView.height
        if (sourceWidth <= 0 || sourceHeight <= 0) return null
        val outHeight = (outWidth.toFloat() * sourceHeight / sourceWidth).toInt().coerceAtLeast(1)
        return try {
            val bitmap = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val scale = outWidth.toFloat() / sourceWidth
            canvas.scale(scale, scale)
            webView.draw(canvas)
            compressSnapshot(bitmap, outWidth)
        } catch (e: Throwable) {
            null
        }
    }

    private fun compressSnapshot(bitmap: Bitmap, outWidth: Int): ByteArray? {
        return try {
            val scaled = if (bitmap.width == outWidth) {
                bitmap
            } else {
                val h = (outWidth.toFloat() * bitmap.height / bitmap.width).toInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(bitmap, outWidth, h, true)
            }
            val stream = ByteArrayOutputStream()
            // 反正要糊掉，质量压低一点，一张图 20~40KB。
            scaled.compress(Bitmap.CompressFormat.JPEG, 52, stream)
            val bytes = stream.toByteArray()
            stream.close()
            if (!scaled.isRecycled) scaled.recycle()
            if (scaled !== bitmap && !bitmap.isRecycled) bitmap.recycle()
            bytes
        } catch (e: Throwable) {
            null
        }
    }

    private fun findFlutterView(root: View): View? {
        if (root is io.flutter.embedding.android.FlutterView) return root
        if (root is ViewGroup) {
            for (index in 0 until root.childCount) {
                findFlutterView(root.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    /** 视图树里可能有多个 WebView（多标签），取当前可见、面积最大的那个。 */
    @Suppress("DEPRECATION")
    private fun findVisibleWebView(): android.webkit.WebView? {
        val decor = window?.decorView ?: return null
        val candidates = ArrayList<android.webkit.WebView>()
        collectWebViews(decor, candidates)
        var best: android.webkit.WebView? = null
        var bestArea = 0
        val rect = Rect()
        for (view in candidates) {
            if (!view.isShown) continue
            if (!view.getGlobalVisibleRect(rect)) continue
            val area = rect.width() * rect.height()
            if (area > bestArea) {
                bestArea = area
                best = view
            }
        }
        return best
    }

    private fun collectWebViews(root: View, out: MutableList<android.webkit.WebView>) {
        if (root is android.webkit.WebView) {
            out.add(root)
            return
        }
        if (root is ViewGroup) {
            for (index in 0 until root.childCount) {
                collectWebViews(root.getChildAt(index), out)
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
