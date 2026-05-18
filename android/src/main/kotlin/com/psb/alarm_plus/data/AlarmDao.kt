package com.psb.alarm_plus.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface AlarmDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insertOrReplace(entity: AlarmEntity)

    @Query("SELECT * FROM alarms WHERE id = :id LIMIT 1")
    fun getById(id: String): AlarmEntity?

    @Query("SELECT * FROM alarms ORDER BY scheduled_time_utc_ms ASC")
    fun getAll(): List<AlarmEntity>

    @Query("DELETE FROM alarms WHERE id = :id")
    fun deleteById(id: String)

    @Query(
        """
        UPDATE alarms
        SET
            status = :status,
            updated_at_ms = :updatedAtMs,
            last_triggered_at_ms = :lastTriggeredAtMs,
            last_drift_ms = :lastDriftMs,
            retry_count = :retryCount,
            next_retry_at_ms = :nextRetryAtMs,
            platform_meta_json = :platformMetaJson
        WHERE id = :id
        """
    )
    fun updateTrigger(
        id: String,
        status: String,
        updatedAtMs: Long,
        lastTriggeredAtMs: Long?,
        lastDriftMs: Long?,
        retryCount: Int,
        nextRetryAtMs: Long?,
        platformMetaJson: String?
    )

    @Query(
        """
        UPDATE alarms
        SET
            status = :status,
            updated_at_ms = :updatedAtMs,
            retry_count = :retryCount,
            next_retry_at_ms = :nextRetryAtMs
        WHERE id = :id
        """
    )
    fun updateStatus(
        id: String,
        status: String,
        updatedAtMs: Long,
        retryCount: Int,
        nextRetryAtMs: Long?
    )
}

