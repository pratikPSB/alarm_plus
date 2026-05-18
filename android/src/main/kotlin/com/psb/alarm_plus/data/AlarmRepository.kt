package com.psb.alarm_plus.data

import android.content.Context
import com.psb.alarm_plus.core.AlarmConstants
import com.psb.alarm_plus.core.AlarmJson
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class AlarmRepository private constructor(context: Context) {
    private val dao: AlarmDao = AlarmDatabase.getInstance(context).alarmDao()

    fun upsertScheduled(
        id: String,
        scheduledTimeUtcMs: Long,
        scheduledTimeLocalIso: String,
        payloadJson: String?,
        status: String = AlarmConstants.STATUS_SCHEDULED,
        retryCount: Int = 0,
        nextRetryAtMs: Long? = null,
        platformMeta: Map<String, Any?> = emptyMap()
    ): AlarmEntity {
        val now = System.currentTimeMillis()
        val existing = dao.getById(id)
        val entity = AlarmEntity(
            id = id,
            scheduledTimeUtcMs = scheduledTimeUtcMs,
            scheduledTimeLocalIso = scheduledTimeLocalIso,
            payloadJson = payloadJson,
            status = status,
            createdAtMs = existing?.createdAtMs ?: now,
            updatedAtMs = now,
            lastTriggeredAtMs = existing?.lastTriggeredAtMs,
            lastDriftMs = existing?.lastDriftMs,
            retryCount = retryCount,
            nextRetryAtMs = nextRetryAtMs,
            platformMetaJson = AlarmJson.toJson(platformMeta)
        )
        dao.insertOrReplace(entity)
        return entity
    }

    fun getById(id: String): AlarmEntity? {
        return dao.getById(id)
    }

    fun getAll(): List<AlarmEntity> {
        return dao.getAll()
    }

    fun deleteById(id: String) {
        dao.deleteById(id)
    }

    fun markTriggered(
        id: String,
        actualTriggeredAtMs: Long,
        driftMs: Long,
        retryCount: Int,
        nextRetryAtMs: Long?,
        platformMeta: Map<String, Any?> = emptyMap()
    ) {
        dao.updateTrigger(
            id = id,
            status = AlarmConstants.STATUS_TRIGGERED,
            updatedAtMs = System.currentTimeMillis(),
            lastTriggeredAtMs = actualTriggeredAtMs,
            lastDriftMs = driftMs,
            retryCount = retryCount,
            nextRetryAtMs = nextRetryAtMs,
            platformMetaJson = AlarmJson.toJson(platformMeta)
        )
    }

    fun markStopped(id: String) {
        dao.updateStatus(
            id = id,
            status = AlarmConstants.STATUS_STOPPED,
            updatedAtMs = System.currentTimeMillis(),
            retryCount = 0,
            nextRetryAtMs = null
        )
    }

    fun markCanceled(id: String) {
        dao.updateStatus(
            id = id,
            status = AlarmConstants.STATUS_CANCELED,
            updatedAtMs = System.currentTimeMillis(),
            retryCount = 0,
            nextRetryAtMs = null
        )
    }

    fun markSnoozed(id: String, retryCount: Int) {
        dao.updateStatus(
            id = id,
            status = AlarmConstants.STATUS_SNOOZED,
            updatedAtMs = System.currentTimeMillis(),
            retryCount = retryCount,
            nextRetryAtMs = null
        )
    }

    fun markError(id: String, retryCount: Int, nextRetryAtMs: Long?) {
        dao.updateStatus(
            id = id,
            status = AlarmConstants.STATUS_ERROR,
            updatedAtMs = System.currentTimeMillis(),
            retryCount = retryCount,
            nextRetryAtMs = nextRetryAtMs
        )
    }

    fun toPlatformMap(entity: AlarmEntity): Map<String, Any?> {
        return mapOf(
            "id" to entity.id,
            "scheduledTimeUtcMs" to entity.scheduledTimeUtcMs,
            "scheduledTimeLocalIso" to entity.scheduledTimeLocalIso,
            "payloadJson" to entity.payloadJson,
            "status" to entity.status,
            "createdAtMs" to entity.createdAtMs,
            "updatedAtMs" to entity.updatedAtMs,
            "lastTriggeredAtMs" to entity.lastTriggeredAtMs,
            "lastDriftMs" to entity.lastDriftMs,
            "retryCount" to entity.retryCount,
            "nextRetryAtMs" to entity.nextRetryAtMs,
            "platformMeta" to AlarmJson.toMap(entity.platformMetaJson)
        )
    }

    companion object {
        @Volatile
        private var instance: AlarmRepository? = null
        private val formatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME

        fun getInstance(context: Context): AlarmRepository {
            return instance ?: synchronized(this) {
                instance ?: AlarmRepository(context.applicationContext).also { instance = it }
            }
        }

        fun localIsoFromUtcMillis(utcMillis: Long): String {
            return Instant.ofEpochMilli(utcMillis)
                .atZone(ZoneId.systemDefault())
                .format(formatter)
        }
    }
}

