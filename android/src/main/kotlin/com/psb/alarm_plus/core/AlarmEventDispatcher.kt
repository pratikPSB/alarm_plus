package com.psb.alarm_plus.core

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentLinkedQueue

object AlarmEventDispatcher {
    private val handler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null
    private val pending = ConcurrentLinkedQueue<Map<String, Any?>>()

    fun setSink(eventSink: EventChannel.EventSink?) {
        handler.post {
            sink = eventSink
            if (eventSink == null) {
                return@post
            }
            while (true) {
                val item = pending.poll() ?: break
                eventSink.success(item)
            }
        }
    }

    fun emit(payload: Map<String, Any?>) {
        handler.post {
            val currentSink = sink
            if (currentSink == null) {
                pending.offer(payload)
                return@post
            }
            currentSink.success(payload)
        }
    }
}

