package com.example.app_sage

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
    // Read the last saved LLM summary from SharedPreferences, fallback to intent payload or heartbeat
    val prefs = context.getSharedPreferences("app_sage_prefs", Context.MODE_PRIVATE)
    val saved = prefs.getString("last_summary", null)
    val body = saved ?: intent?.getStringExtra("payload") ?: "AppSage heartbeat"
        val channelId = "app_sage_native_channel"

        // Ensure notification channel exists (for Android O+)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val chan = android.app.NotificationChannel(channelId, "AppSage Native", android.app.NotificationManager.IMPORTANCE_HIGH)
            chan.description = "Native notifications from AppSage"
            val nmSys = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            nmSys.createNotificationChannel(chan)
        }

        // Build a notification that opens MainActivity with payload
        val launchIntent = Intent(context, MainActivity::class.java)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        launchIntent.putExtra("payload", body)

        val pending = android.app.PendingIntent.getActivity(context, 0, launchIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)

        // Compute next notification time from saved alarm_minutes if available
        val minutes = prefs.getInt("alarm_minutes", 0)
        val nextText = if (minutes > 0) {
            val now = java.util.Calendar.getInstance()
            now.add(java.util.Calendar.MINUTE, minutes)
            val hh = now.get(java.util.Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
            val mm = now.get(java.util.Calendar.MINUTE).toString().padStart(2, '0')
            "Next: $hh:$mm"
        } else {
            "Next: unknown"
        }

        val notif = NotificationCompat.Builder(context, channelId)
            .setContentTitle("AppSage (native)")
            .setContentText(body)
            .setSubText(nextText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(1001, notif)

        // Send a broadcast so the app (if running) can update its UI about the fired notification
        try {
            val b = android.content.Intent("com.app_sage.NOTIF_FIRED")
            b.putExtra("next_time", prefs.getString("next_notification", ""))
            b.putExtra("summary", body)
            context.sendBroadcast(b)
        } catch (e: Exception) {
            // no-op
        }
    }
}
