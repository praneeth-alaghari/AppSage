package com.example.app_sage

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val body = intent?.getStringExtra("payload") ?: "AppSage heartbeat"
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

        val notif = NotificationCompat.Builder(context, channelId)
            .setContentTitle("AppSage (native)")
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(1001, notif)
    }
}
