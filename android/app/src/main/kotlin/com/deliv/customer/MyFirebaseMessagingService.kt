package com.deliv.customer

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class MyFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val sound = message.data["sound"] ?: return

        when (sound) {
            "ring" -> {
                if (!isAppInForeground()) {
                    if (Settings.canDrawOverlays(this)) {
                        val intent = Intent(this, DriverArrivalActivity::class.java).apply {
                            putExtra("driverName", message.data["driverName"] ?: "السائق")
                            putExtra("driverPhoto", message.data["driverPhoto"] ?: "")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                    } else {
                        showFallbackNotification(
                            title = message.data["driverName"] ?: "السائق",
                            body = "السائق وصل — اضغط للرد",
                            channelId = "driver_arrival_channel",
                            channelName = "وصول السائق",
                            notificationId = 7777,
                            targetIntent = Intent(this, DriverArrivalActivity::class.java).apply {
                                putExtra("driverName", message.data["driverName"] ?: "السائق")
                                putExtra("driverPhoto", message.data["driverPhoto"] ?: "")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                        )
                    }
                }
            }
            "alternative" -> {
                if (!isAppInForeground()) {
                    val productName = message.data["productName"] ?: ""
                    val alternativeName = message.data["alternativeName"] ?: ""
                    val alternativePrice = message.data["alternativePrice"] ?: ""
                    val orderId = message.data["orderId"] ?: ""
                    val driverName = message.data["driverName"] ?: "السائق"
                    val driverPhoto = message.data["driverPhoto"] ?: ""

                    if (Settings.canDrawOverlays(this)) {
                        val intent = Intent(this, AlternativeActivity::class.java).apply {
                            putExtra("driverName", driverName)
                            putExtra("driverPhoto", driverPhoto)
                            putExtra("productName", productName)
                            putExtra("alternativeName", alternativeName)
                            putExtra("alternativePrice", alternativePrice)
                            putExtra("orderId", orderId)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                    } else {
                        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            putExtra("openOrderId", orderId)
                        } ?: return
                        showFallbackNotification(
                            title = "بديل مقترح: $alternativeName",
                            body = "السائق يقترح بديل لـ $productName — اضغط للمراجعة",
                            channelId = "alternative_channel",
                            channelName = "بديل المنتج",
                            notificationId = 8888,
                            targetIntent = openIntent
                        )
                    }
                }
            }
            "delivered" -> {
                if (!isAppInForeground()) {
                    val orderId = message.data["orderId"] ?: ""
                    val driverName = message.data["driverName"] ?: "السائق"
                    val driverPhoto = message.data["driverPhoto"] ?: ""
                    val driverId = message.data["driverId"] ?: ""

                    if (Settings.canDrawOverlays(this)) {
                        val intent = Intent(this, DeliveredActivity::class.java).apply {
                            putExtra("driverName", driverName)
                            putExtra("driverPhoto", driverPhoto)
                            putExtra("orderId", orderId)
                            putExtra("driverId", driverId)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                    } else {
                        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            putExtra("openOrderId", orderId)
                        } ?: return
                        showFallbackNotification(
                            title = "تم التوصيل",
                            body = "طلبية $orderId تم توصيلها — اضغط للتأكيد",
                            channelId = "delivered_channel",
                            channelName = "تأكيد التوصيل",
                            notificationId = 9999,
                            targetIntent = openIntent
                        )
                    }
                }
            }
        }
    }

    private fun showFallbackNotification(
        title: String,
        body: String,
        channelId: String,
        channelName: String,
        notificationId: Int,
        targetIntent: Intent
    ) {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = channelName
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            targetIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .setOngoing(true)
            .setContentIntent(pendingIntent)

        notificationManager.notify(notificationId, builder.build())
    }

    private fun isAppInForeground(): Boolean {
        val appProcessInfo = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(appProcessInfo)
        return appProcessInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
    }
}
