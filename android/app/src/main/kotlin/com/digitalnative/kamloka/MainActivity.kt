package com.digitalnative.kamloka

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import kotlin.math.roundToInt
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val appInfoChannel = "kamloka/app_info"
    private val watermarkChannel = "kamloka/watermark"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, watermarkChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "composite") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val arguments = call.arguments as? Map<*, *>
                val sourcePath = arguments?.get("sourcePath") as? String
                val outputPath = arguments?.get("outputPath") as? String
                val watermarkBytes = arguments?.get("watermarkBytes") as? ByteArray
                val widthRatio = (arguments?.get("widthRatio") as? Number)?.toDouble() ?: 0.75
                val bottomMarginRatio =
                    (arguments?.get("bottomMarginRatio") as? Number)?.toDouble() ?: 0.035
                val jpegQuality =
                    (arguments?.get("jpegQuality") as? Number)?.toInt()?.coerceIn(75, 100) ?: 95

                if (sourcePath.isNullOrBlank() || outputPath.isNullOrBlank() ||
                    watermarkBytes == null || watermarkBytes.isEmpty()
                ) {
                    result.error(
                        "INVALID_WATERMARK_ARGUMENTS",
                        "Data foto atau watermark tidak lengkap.",
                        null
                    )
                    return@setMethodCallHandler
                }

                // Operasi bitmap dijalankan di worker agar UI thread tetap responsif.
                Thread {
                    try {
                        compositeWatermark(
                            sourcePath = sourcePath,
                            outputPath = outputPath,
                            watermarkBytes = watermarkBytes,
                            widthRatio = widthRatio,
                            bottomMarginRatio = bottomMarginRatio,
                            jpegQuality = jpegQuality
                        )
                        runOnUiThread { result.success(outputPath) }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error(
                                "WATERMARK_COMPOSITE_FAILED",
                                "Watermark tidak dapat ditempelkan ke foto.",
                                error.message
                            )
                        }
                    }
                }.start()
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appInfoChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVersionName" -> {
                        try {
                            @Suppress("DEPRECATION")
                            val versionName = packageManager
                                .getPackageInfo(packageName, 0)
                                .versionName
                            result.success(versionName)
                        } catch (error: Exception) {
                            result.error(
                                "VERSION_READ_FAILED",
                                "Tidak dapat membaca versi aplikasi.",
                                error.message
                            )
                        }
                    }

                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL tidak valid.", null)
                        } else {
                            try {
                                startActivity(
                                    Intent(Intent.ACTION_VIEW, Uri.parse(url))
                                )
                                result.success(true)
                            } catch (error: Exception) {
                                result.error(
                                    "OPEN_URL_FAILED",
                                    "Tidak dapat membuka tautan.",
                                    error.message
                                )
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun compositeWatermark(
        sourcePath: String,
        outputPath: String,
        watermarkBytes: ByteArray,
        widthRatio: Double,
        bottomMarginRatio: Double,
        jpegQuality: Int
    ) {
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = true
        }
        val photo = BitmapFactory.decodeFile(sourcePath, options)
            ?: throw IllegalArgumentException("Foto asli tidak dapat dibaca.")
        var watermark: Bitmap? = null
        var scaledWatermark: Bitmap? = null

        try {
            watermark = BitmapFactory.decodeByteArray(
                watermarkBytes, 0, watermarkBytes.size
            ) ?: throw IllegalArgumentException("PNG watermark tidak dapat dibaca.")

            val targetWidth = (photo.width * widthRatio.coerceIn(0.1, 1.0))
                .roundToInt()
                .coerceIn(1, photo.width)
            val targetHeight = (watermark.height.toDouble() * targetWidth / watermark.width)
                .roundToInt()
                .coerceAtLeast(1)
            scaledWatermark = Bitmap.createScaledBitmap(
                watermark, targetWidth, targetHeight, true
            )

            val left = ((photo.width - targetWidth) / 2).coerceAtLeast(0)
            val bottomMargin = (photo.height * bottomMarginRatio.coerceIn(0.0, 0.2))
                .roundToInt()
            val top = (photo.height - targetHeight - bottomMargin).coerceAtLeast(0)

            val canvas = Canvas(photo)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            canvas.drawBitmap(
                scaledWatermark,
                null,
                Rect(left, top, left + targetWidth, top + targetHeight),
                paint
            )

            File(outputPath).parentFile?.mkdirs()
            FileOutputStream(File(outputPath)).use { output ->
                if (!photo.compress(Bitmap.CompressFormat.JPEG, jpegQuality, output)) {
                    throw IllegalStateException("JPEG watermark gagal disimpan.")
                }
                output.flush()
            }
        } finally {
            if (scaledWatermark !== watermark) scaledWatermark?.recycle()
            watermark?.recycle()
            photo.recycle()
        }
    }
}
