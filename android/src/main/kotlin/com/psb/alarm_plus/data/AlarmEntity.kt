package com.psb.alarm_plus.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "alarms")
data class AlarmEntity(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,
    @ColumnInfo(name = "scheduled_time_utc_ms")
    val scheduledTimeUtcMs: Long,
    @ColumnInfo(name = "scheduled_time_local_iso")
    val scheduledTimeLocalIso: String,
    @ColumnInfo(name = "payload_json")
    val payloadJson: String?,
    @ColumnInfo(name = "status")
    val status: String,
    @ColumnInfo(name = "created_at_ms")
    val createdAtMs: Long,
    @ColumnInfo(name = "updated_at_ms")
    val updatedAtMs: Long,
    @ColumnInfo(name = "last_triggered_at_ms")
    val lastTriggeredAtMs: Long?,
    @ColumnInfo(name = "last_drift_ms")
    val lastDriftMs: Long?,
    @ColumnInfo(name = "retry_count")
    val retryCount: Int,
    @ColumnInfo(name = "next_retry_at_ms")
    val nextRetryAtMs: Long?,
    @ColumnInfo(name = "platform_meta_json")
    val platformMetaJson: String?
)

