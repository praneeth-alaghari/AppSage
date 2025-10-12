package com.example.app_sage

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "app_sage/package_info"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getAppLabel" -> {
					val packageName = call.argument<String>("package")
					if (packageName == null) {
						result.error("NO_PACKAGE", "No package provided", null)
						return@setMethodCallHandler
					}
					try {
						val pm = applicationContext.packageManager
						val info = pm.getApplicationInfo(packageName, 0)
						val label = pm.getApplicationLabel(info).toString()
						result.success(label)
					} catch (e: PackageManager.NameNotFoundException) {
						result.success(null)
					}
				}
				"openUsageAccessSettings" -> {
					try {
						val intent = android.content.Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
						intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
						applicationContext.startActivity(intent)
						result.success(true)
					} catch (e: Exception) {
						result.error("INTENT_ERROR", "Failed to open settings: ${e.message}", null)
					}
				}
				"getAppIcon" -> {
					val packageName = call.argument<String>("package")
					if (packageName == null) {
						result.error("NO_PACKAGE", "No package provided", null)
						return@setMethodCallHandler
					}
					try {
						val pm = applicationContext.packageManager
						val info = pm.getApplicationInfo(packageName, 0)
						val drawable = pm.getApplicationIcon(info)
						// Convert drawable to bitmap then to PNG bytes
						val bitmap = if (drawable is android.graphics.drawable.BitmapDrawable) {
							drawable.bitmap
						} else {
							val width = drawable.intrinsicWidth
							val height = drawable.intrinsicHeight
							val bmp = android.graphics.Bitmap.createBitmap(
								if (width > 0) width else 1,
								if (height > 0) height else 1,
								android.graphics.Bitmap.Config.ARGB_8888
							)
							val canvas = android.graphics.Canvas(bmp)
							drawable.setBounds(0, 0, canvas.width, canvas.height)
							drawable.draw(canvas)
							bmp
						}
						val stream = java.io.ByteArrayOutputStream()
						bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
						val bytes = stream.toByteArray()
						val base64 = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
						result.success(base64)
					} catch (e: PackageManager.NameNotFoundException) {
						result.success(null)
					} catch (e: Exception) {
						result.error("ICON_ERROR", "${e.message}", null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
