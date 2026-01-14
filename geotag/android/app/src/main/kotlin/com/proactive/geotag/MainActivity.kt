package com.proactive.geotag

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "proactive/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                if (call.method == "saveImage") {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename")

                    try {
                        val values = ContentValues().apply {
                            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                            if (Build.VERSION.SDK_INT >= 29) {
                                put(
                                    MediaStore.Images.Media.RELATIVE_PATH,
                                    "Pictures/ProActive"
                                )
                            }
                        }

                        val uri = contentResolver.insert(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            values
                        )

                        if (uri != null) {
                            val stream = contentResolver.openOutputStream(uri)
                            if (stream != null) {
                                stream.write(bytes)
                                stream.close()
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }

                } else {
                    result.notImplemented()
                }
            }
    }
}