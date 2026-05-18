package com.psb.alarm_plus.core

import android.util.Log
import com.psb.alarm_plus.BuildConfig

object AlarmLog {
    private const val TAG = "AlarmPlus"

    fun v(stage: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.v(TAG, "[$stage] $message")
        }
    }

    fun d(stage: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, "[$stage] $message")
        }
    }

    fun i(stage: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.i(TAG, "[$stage] $message")
        }
    }

    fun w(stage: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.w(TAG, "[$stage] $message")
        }
    }

    fun e(stage: String, message: String, throwable: Throwable? = null) {
        if (BuildConfig.DEBUG) {
            Log.e(TAG, "[$stage] $message", throwable)
        }
    }
}

