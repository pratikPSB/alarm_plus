package com.psb.alarm_plus.core

import kotlin.math.absoluteValue

object AlarmIds {
    fun requestCodeFor(id: String): Int {
        return (id.hashCode().absoluteValue % 600000) + 1000
    }

    fun notificationIdFor(id: String): Int {
        return (id.hashCode().absoluteValue % 600000) + 30000
    }
}

