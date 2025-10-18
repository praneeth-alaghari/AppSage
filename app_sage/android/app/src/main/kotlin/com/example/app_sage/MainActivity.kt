package com.example.app_sage

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "app_sage/package_info"
	private val NATIVE_ALARM_CHANNEL = "app_sage/native_alarm"

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

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_ALARM_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"startNativeAlarm" -> {
					val minutes = call.argument<Int>("minutes") ?: 5
					try {
						val context = applicationContext
						val am = context.getSystemService(android.content.Context.ALARM_SERVICE) as android.app.AlarmManager
						val intent = android.content.Intent(context, AlarmReceiver::class.java)
						intent.putExtra("payload", "Native Alarm scheduled every $minutes minutes")
						val pending = android.app.PendingIntent.getBroadcast(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
						val trigger = System.currentTimeMillis() + minutes * 60L * 1000L
						am.setInexactRepeating(android.app.AlarmManager.RTC_WAKEUP, trigger, minutes * 60L * 1000L, pending)
						result.success(true)
					} catch (e: Exception) {
						result.error("ALARM_ERROR", "Failed to start native alarm: ${e.message}", null)
					}
				}
				"stopNativeAlarm" -> {
					try {
						val context = applicationContext
						val am = context.getSystemService(android.content.Context.ALARM_SERVICE) as android.app.AlarmManager
						val intent = android.content.Intent(context, AlarmReceiver::class.java)
						val pending = android.app.PendingIntent.getBroadcast(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
						am.cancel(pending)
						result.success(true)
					} catch (e: Exception) {
						result.error("ALARM_ERROR", "Failed to stop native alarm: ${e.message}", null)
					}
				}
				"showNativeNotification" -> {
					val title = call.argument<String>("title") ?: "AppSage"
					val body = call.argument<String>("body") ?: ""
					try {
						val context = applicationContext
						val nm = androidx.core.app.NotificationManagerCompat.from(context)
						val channelId = "app_sage_native_channel"
						if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
							val chan = android.app.NotificationChannel(channelId, "AppSage Native", android.app.NotificationManager.IMPORTANCE_HIGH)
							chan.description = "Native notifications from AppSage"
							val nmSys = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
							nmSys.createNotificationChannel(chan)
						}
						val intent = android.content.Intent(context, MainActivity::class.java)
						intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK)
						intent.putExtra("payload", body)
						val pendingIntent = android.app.PendingIntent.getActivity(context, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
						val notif = androidx.core.app.NotificationCompat.Builder(context, channelId)
							.setContentTitle(title)
							.setContentText(body)
							.setSmallIcon(R.mipmap.ic_launcher)
							.setContentIntent(pendingIntent)
							.setAutoCancel(true)
							.build()
						nm.notify(1001, notif)
						result.success(true)
					} catch (e: Exception) {
						result.error("NOTIF_ERROR", "Failed to show native notification: ${e.message}", null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
