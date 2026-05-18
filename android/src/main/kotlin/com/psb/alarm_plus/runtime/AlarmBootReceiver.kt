package com.psb.alarm_plus.runtime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.psb.alarm_plus.core.AlarmLog
import com.psb.alarm_plus.core.AlarmScheduler
import com.psb.alarm_plus.data.AlarmRepository
import java.util.concurrent.Executors

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        executor.execute {
            try {
                val repository = AlarmRepository.getInstance(context)
                val alarms = repository.getAll()
                val scheduler = AlarmScheduler(context)
                scheduler.rescheduleAll(alarms)
                AlarmLog.i("boot", "Rescheduled alarms after ${intent.action}")
            } catch (error: Throwable) {
                AlarmLog.e("boot", "Failed to reschedule alarms", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        private val executor = Executors.newSingleThreadExecutor()
    }
}
