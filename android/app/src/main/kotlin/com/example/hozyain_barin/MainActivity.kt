package com.example.hozyain_barin

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import com.yandex.mapkit.MapKitFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val channelName = "native_image_picker"
    private val runtimeConfigChannelName = "hozyain/runtime_config"
    private val requestPickImages = 5012
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCameraUri: Uri? = null
    private var pendingCameraFile: File? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must be set before yandex_mapkit plugin initializes its MapKit.
        val apiKey = BuildConfig.YANDEX_MAPKIT_API_KEY
        if (apiKey.isNotBlank()) {
            MapKitFactory.setApiKey(apiKey)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickImages") {
                    if (pendingResult != null) {
                        result.error("busy", "Image picker already active", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    openImageChooser()
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, runtimeConfigChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getYandexSuggestApiKey") {
                    result.success(BuildConfig.YANDEX_SUGGEST_API_KEY)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openImageChooser() {
        val filesIntent = buildSamsungFilesIntent() ?: Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val galleryBase = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val galleryIntent = resolvePreferredIntent(
            galleryBase,
            listOf("com.samsung.android.gallery.app", "com.sec.android.gallery3d", "com.google.android.apps.photos")
        ) ?: galleryBase

        val cameraBase = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        var cameraAvailable = cameraBase.resolveActivity(packageManager) != null
        if (cameraAvailable) {
            val photoFile = createTempImageFile()
            if (photoFile != null) {
                val uri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    photoFile
                )
                pendingCameraUri = uri
                pendingCameraFile = photoFile
                cameraBase.putExtra(MediaStore.EXTRA_OUTPUT, uri)
                cameraBase.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)

                val resInfoList = packageManager.queryIntentActivities(cameraBase, PackageManager.MATCH_DEFAULT_ONLY)
                for (resolveInfo in resInfoList) {
                    val packageName = resolveInfo.activityInfo.packageName
                    grantUriPermission(
                        packageName,
                        uri,
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                }
            } else {
                cameraAvailable = false
            }
        }
        val cameraIntent = if (cameraAvailable) {
            resolvePreferredIntent(
                cameraBase,
                listOf("com.sec.android.app.camera", "com.samsung.android.camera")
            ) ?: cameraBase
        } else {
            cameraBase
        }

        val orderedIntents = ArrayList<Intent>()
        if (cameraAvailable) orderedIntents.add(cameraIntent)
        if (galleryIntent.resolveActivity(packageManager) != null) orderedIntents.add(galleryIntent)
        if (filesIntent.resolveActivity(packageManager) != null) orderedIntents.add(filesIntent)

        if (orderedIntents.isEmpty()) {
            return
        }

        val baseIntent = orderedIntents.removeAt(orderedIntents.size - 1)
        val chooser = Intent.createChooser(baseIntent, "Выберите действие")
        if (orderedIntents.isNotEmpty()) {
            chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, orderedIntents.toTypedArray())
        }
        startActivityForResult(chooser, requestPickImages)
    }

    private fun resolvePreferredIntent(
        base: Intent,
        preferredPackages: List<String>,
        excludedPackages: Set<String> = emptySet()
    ): Intent? {
        val handlers = packageManager.queryIntentActivities(base, PackageManager.MATCH_DEFAULT_ONLY)
        if (handlers.isEmpty()) return null
        for (pkg in preferredPackages) {
            val match = handlers.firstOrNull { it.activityInfo.packageName == pkg }
            if (match != null) {
                return Intent(base).apply {
                    component = ComponentName(match.activityInfo.packageName, match.activityInfo.name)
                    setPackage(match.activityInfo.packageName)
                }
            }
        }
        val fallback = handlers.firstOrNull { !excludedPackages.contains(it.activityInfo.packageName) }
        if (fallback != null) {
            return Intent(base).apply {
                component = ComponentName(fallback.activityInfo.packageName, fallback.activityInfo.name)
                setPackage(fallback.activityInfo.packageName)
            }
        }
        return null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestPickImages) return

        val result = pendingResult
        pendingResult = null

        if (result == null) return
        if (resultCode != Activity.RESULT_OK) {
            cleanupPendingCamera()
            result.success(emptyList<String>())
            return
        }

        val uris = mutableListOf<Uri>()
        val clipData = data?.clipData
        if (clipData != null) {
            for (i in 0 until clipData.itemCount) {
                uris.add(clipData.getItemAt(i).uri)
            }
        } else if (data?.data != null) {
            uris.add(data.data!!)
        } else if (pendingCameraUri != null) {
            uris.add(pendingCameraUri!!)
        }

        val paths = uris.mapNotNull { uri ->
            if (uri == pendingCameraUri && pendingCameraFile != null) {
                pendingCameraFile?.absolutePath
            } else {
                copyToCache(uri)
            }
        }
        cleanupPendingCamera()
        result.success(paths)
    }

    private fun cleanupPendingCamera() {
        pendingCameraUri = null
        pendingCameraFile = null
    }

    private fun createTempImageFile(): File? {
        return try {
            val dir = getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: externalCacheDir ?: cacheDir
            File.createTempFile("review_", ".jpg", dir)
        } catch (e: Exception) {
            null
        }
    }

    private fun copyToCache(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        val fileName = queryFileName(uri) ?: "image_${System.currentTimeMillis()}.jpg"
        val outFile = File(cacheDir, fileName)
        return try {
            val inputStream: InputStream = contentResolver.openInputStream(uri) ?: return null
            inputStream.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            }
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun buildSamsungFilesIntent(): Intent? {
        val packages = listOf("com.sec.android.app.myfiles", "com.samsung.android.app.myfiles")
        val actions = listOf(
            "com.sec.android.app.myfiles.PICK_DATA_MULTIPLE",
            "com.sec.android.app.myfiles.PICK_DATA",
            Intent.ACTION_GET_CONTENT,
            Intent.ACTION_OPEN_DOCUMENT
        )
        for (pkg in packages) {
            for (action in actions) {
                val intent = Intent(action).apply {
                    addCategory(Intent.CATEGORY_DEFAULT)
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra("CONTENT_TYPE", "image/*")
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    type = "image/*"
                    setPackage(pkg)
                }
                val matches = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                if (matches.isNotEmpty()) {
                    val match = matches.first()
                    return Intent(intent).apply {
                        component = ComponentName(match.activityInfo.packageName, match.activityInfo.name)
                        setPackage(match.activityInfo.packageName)
                    }
                }
            }
        }
        return null
    }

    private fun queryFileName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, null, null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else null
        } catch (e: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }
}
