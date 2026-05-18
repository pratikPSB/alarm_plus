package com.psb.alarm_plus.runtime.background

import android.content.Context
import com.psb.alarm_plus.core.AlarmConstants
import io.flutter.view.FlutterCallbackInformation

class AlarmBackgroundIsolatePreferences(private val context: Context) {
    private fun prefs() =
        context.getSharedPreferences(AlarmConstants.PREFS_NAME, Context.MODE_PRIVATE)

    fun saveHandles(dispatcherHandle: Long, callbackHandle: Long) {
        prefs().edit()
            .putLong(AlarmConstants.PREF_BG_DISPATCHER_HANDLE, dispatcherHandle)
            .putLong(AlarmConstants.PREF_BG_CALLBACK_HANDLE, callbackHandle)
            .apply()
    }

    fun getCallbackHandle(): Long? {
        val value = prefs().getLong(AlarmConstants.PREF_BG_CALLBACK_HANDLE, -1L)
        return if (value <= 0L) null else value
    }

    fun lookupDispatcherHandle(): FlutterCallbackInformation? {
        val value = prefs().getLong(AlarmConstants.PREF_BG_DISPATCHER_HANDLE, -1L)
        if (value <= 0L) {
            return null
        }
        return FlutterCallbackInformation.lookupCallbackInformation(value)
    }
}

