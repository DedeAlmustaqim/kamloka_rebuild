package com.digitalnative.kamloka

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val appInfoChannel = "kamloka/app_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}
