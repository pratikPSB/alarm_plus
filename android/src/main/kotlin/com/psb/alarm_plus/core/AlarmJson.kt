package com.psb.alarm_plus.core

import com.google.gson.Gson
import com.google.gson.JsonSyntaxException

object AlarmJson {
    private val gson = Gson()

    fun toJson(map: Map<String, Any?>?): String? {
        if (map == null) {
            return null
        }
        return gson.toJson(map)
    }

    fun toMap(json: String?): Map<String, Any?> {
        if (json.isNullOrBlank()) {
            return emptyMap()
        }
        return try {
            @Suppress("UNCHECKED_CAST")
            gson.fromJson(json, Map::class.java) as? Map<String, Any?> ?: emptyMap()
        } catch (_: JsonSyntaxException) {
            emptyMap()
        }
    }
}

