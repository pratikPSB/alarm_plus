package com.psb.alarm_plus.core

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper

class PermissionSettingsFlow(
    private val activity: Activity,
    intents: List<Intent>,
    private val onComplete: () -> Unit
) : Application.ActivityLifecycleCallbacks {
    private val pending = ArrayDeque(intents)
    private val handler = Handler(Looper.getMainLooper())
    private var awaitingPause = false
    private var awaitingResume = false
    private var finished = false
    private val launchTimeout = Runnable {
        if (awaitingPause) {
            launchNext()
        }
    }

    fun start() {
        activity.application.registerActivityLifecycleCallbacks(this)
        launchNext()
    }

    fun finish() {
        if (finished) {
            return
        }
        finished = true
        handler.removeCallbacks(launchTimeout)
        activity.application.unregisterActivityLifecycleCallbacks(this)
        onComplete()
    }

    private fun launchNext() {
        awaitingPause = false
        awaitingResume = false
        while (true) {
            val intent = pending.removeFirstOrNull() ?: return finish()
            try {
                activity.startActivity(intent)
            } catch (error: Throwable) {
                AlarmLog.w("permissions", "Unable to open settings intent=${intent.action}")
                continue
            }
            awaitingPause = true
            handler.postDelayed(launchTimeout, LAUNCH_TIMEOUT_MS)
            return
        }
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity !== this.activity || !awaitingPause) {
            return
        }
        handler.removeCallbacks(launchTimeout)
        awaitingPause = false
        awaitingResume = true
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity !== this.activity || !awaitingResume) {
            return
        }
        launchNext()
    }

    override fun onActivityDestroyed(activity: Activity) {
        if (activity === this.activity) {
            finish()
        }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

    override fun onActivityStarted(activity: Activity) = Unit

    override fun onActivityStopped(activity: Activity) = Unit

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

    private companion object {
        const val LAUNCH_TIMEOUT_MS = 2_000L
    }
}
