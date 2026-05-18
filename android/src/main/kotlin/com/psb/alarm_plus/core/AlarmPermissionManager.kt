package com.psb.alarm_plus.core

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat

class AlarmPermissionManager(private val context: Context) {
    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun getStatus(): Map<String, Any?> {
        val notificationsGranted = notificationsGranted()
        val exactAlarmsGranted = exactAlarmsGranted()
        val fullScreenIntentGranted = fullScreenIntentGranted()
        val canOpenExactAlarmSettings = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        val canOpenFullScreenSettings = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

        return mapOf(
            "notificationsGranted" to notificationsGranted,
            "exactAlarmsGranted" to exactAlarmsGranted,
            "fullScreenIntentGranted" to fullScreenIntentGranted,
            "canOpenExactAlarmSettings" to canOpenExactAlarmSettings,
            "canOpenFullScreenSettings" to canOpenFullScreenSettings,
            "criticalAlertsEligible" to false,
            "platformMeta" to mapOf(
                "sdkInt" to Build.VERSION.SDK_INT,
                "manufacturer" to Build.MANUFACTURER,
                "model" to Build.MODEL
            )
        )
    }

    fun requestFromSettings(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !notificationsGranted()) {
            openNotificationSettings()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !exactAlarmsGranted()) {
            openExactAlarmSettings()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && !fullScreenIntentGranted()) {
            openFullScreenIntentSettings()
        }
        return getStatus()
    }

    private fun notificationsGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun exactAlarmsGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun fullScreenIntentGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            notificationManager.canUseFullScreenIntent()
        } else {
            true
        }
    }

    private fun openExactAlarmSettings() {
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        safeStartActivity(intent)
    }

    private fun openFullScreenIntentSettings() {
        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        safeStartActivity(intent)
    }

    private fun safeStartActivity(intent: Intent) {
        try {
            context.startActivity(intent)
        } catch (error: Throwable) {
            AlarmLog.w("permissions", "Unable to open settings intent=${intent.action}")
        }
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        safeStartActivity(intent)
    }
}
