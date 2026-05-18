package com.psb.alarm_plus.runtime.background

import android.content.Context
import com.psb.alarm_plus.core.AlarmConstants
import com.psb.alarm_plus.core.AlarmLog
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.EventChannel

object AlarmBackgroundActionDispatcher {
    @Volatile
    private var engine: FlutterEngine? = null
    private val eventSink = QueuedActionEventSink()

    @Synchronized
    fun dispatch(context: Context, response: Map<String, Any?>) {
        val prefs = AlarmBackgroundIsolatePreferences(context.applicationContext)
        val callbackHandle = prefs.getCallbackHandle()
        if (callbackHandle == null) {
            return
        }
        eventSink.addItem(response)
        startEngineIfNeeded(context.applicationContext, prefs)
    }

    @Synchronized
    private fun startEngineIfNeeded(
        context: Context,
        prefs: AlarmBackgroundIsolatePreferences
    ) {
        if (engine != null) {
            return
        }

        val dispatcher = prefs.lookupDispatcherHandle()
        if (dispatcher == null) {
            AlarmLog.w("bg_dispatch", "Dispatcher callback info not found")
            return
        }

        val injector = FlutterInjector.instance()
        val loader: FlutterLoader = injector.flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationComplete(context, null)

        val flutterEngine = FlutterEngine(context)
        val channel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AlarmConstants.BACKGROUND_EVENT_CHANNEL
        )
        channel.setStreamHandler(eventSink)

        val bundlePath = loader.findAppBundlePath()
        flutterEngine.dartExecutor.executeDartCallback(
            DartExecutor.DartCallback(context.assets, bundlePath, dispatcher)
        )
        engine = flutterEngine
        AlarmLog.i("bg_dispatch", "Background isolate started")
    }

    private class QueuedActionEventSink : EventChannel.StreamHandler {
        private val cached = mutableListOf<Map<String, Any?>>()
        private var sink: EventChannel.EventSink? = null

        fun addItem(item: Map<String, Any?>) {
            val current = sink
            if (current != null) {
                current.success(item)
            } else {
                cached.add(item)
            }
        }

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
            for (item in cached) {
                events?.success(item)
            }
            cached.clear()
        }

        override fun onCancel(arguments: Any?) {
            sink = null
        }
    }
}

