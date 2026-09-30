package com.safeug.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val channelId = "safeug_emergencies"
    private val manager get() = getSystemService(NotificationManager::class.java)

    private fun permission(): String = if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) "denied" else if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) "denied" else "granted"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(channelId, "Emergency alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "SOS delivery and emergency response updates"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "safeug/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> result.success(permission())
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 && permission() != "granted") {
                        if (permissionResult != null) result.success("denied") else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7401)
                        }
                    } else result.success(permission())
                }
                "show" -> {
                    if (permission() == "granted") {
                        val key = call.argument<String>("id") ?: "safeug"
                        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        val pending = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                        manager.notify(key, 1, builder.setSmallIcon(R.drawable.ic_notification)
                            .setContentTitle(call.argument<String>("title"))
                            .setContentText(call.argument<String>("body"))
                            .setStyle(Notification.BigTextStyle().bigText(call.argument<String>("body")))
                            .setCategory(Notification.CATEGORY_ALARM)
                            .setVisibility(Notification.VISIBILITY_PRIVATE)
                            .setPriority(Notification.PRIORITY_HIGH)
                            .setDefaults(Notification.DEFAULT_ALL)
                            .setAutoCancel(true).setContentIntent(pending).build())
                    }
                    result.success(null)
                }
                "clear" -> { manager.cancelAll(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7401) {
            permissionResult?.success(permission())
            permissionResult = null
        }
    }
}
