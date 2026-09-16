import Foundation

struct AlarmRecord {
    let id: String
    var scheduledTimeUtcMs: Int64
    var scheduledTimeLocalIso: String
    let payloadJson: String?
    var status: String
    let createdAtMs: Int64
    var updatedAtMs: Int64
    var lastTriggeredAtMs: Int64?
    var lastDriftMs: Int64?
    var retryCount: Int
    var platformMeta: [String: Any]

    init(
        id: String,
        scheduledTimeUtcMs: Int64,
        scheduledTimeLocalIso: String,
        payloadJson: String?,
        status: String,
        createdAtMs: Int64,
        updatedAtMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        lastTriggeredAtMs: Int64? = nil,
        lastDriftMs: Int64? = nil,
        retryCount: Int = 0,
        platformMeta: [String: Any] = [:]
    ) {
        self.id = id
        self.scheduledTimeUtcMs = scheduledTimeUtcMs
        self.scheduledTimeLocalIso = scheduledTimeLocalIso
        self.payloadJson = payloadJson
        self.status = status
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
        self.lastTriggeredAtMs = lastTriggeredAtMs
        self.lastDriftMs = lastDriftMs
        self.retryCount = retryCount
        self.platformMeta = platformMeta
    }

    func toMap() -> [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "scheduledTimeUtcMs": scheduledTimeUtcMs,
            "scheduledTimeLocalIso": scheduledTimeLocalIso,
            "status": status,
            "createdAtMs": createdAtMs,
            "updatedAtMs": updatedAtMs,
            "retryCount": retryCount,
            "platformMeta": platformMeta
        ]
        if let payloadJson = payloadJson { map["payloadJson"] = payloadJson }
        if let lastTriggeredAtMs = lastTriggeredAtMs { map["lastTriggeredAtMs"] = lastTriggeredAtMs }
        if let lastDriftMs = lastDriftMs { map["lastDriftMs"] = lastDriftMs }
        return map
    }

    static func fromMap(_ map: [String: Any]) -> AlarmRecord? {
        guard let id = map["id"] as? String,
              let scheduledTimeUtcMs = int64Value(map["scheduledTimeUtcMs"]),
              let status = map["status"] as? String else {
            return nil
        }

        return AlarmRecord(
            id: id,
            scheduledTimeUtcMs: scheduledTimeUtcMs,
            scheduledTimeLocalIso: map["scheduledTimeLocalIso"] as? String ?? "",
            payloadJson: map["payloadJson"] as? String,
            status: status,
            createdAtMs: int64Value(map["createdAtMs"]) ?? Int64(Date().timeIntervalSince1970 * 1000),
            updatedAtMs: int64Value(map["updatedAtMs"]) ?? Int64(Date().timeIntervalSince1970 * 1000),
            lastTriggeredAtMs: int64Value(map["lastTriggeredAtMs"]),
            lastDriftMs: int64Value(map["lastDriftMs"]),
            retryCount: (map["retryCount"] as? Int) ?? 0,
            platformMeta: (map["platformMeta"] as? [String: Any]) ?? [:]
        )
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let v = value as? Int64 { return v }
        if let v = value as? Int { return Int64(v) }
        if let v = value as? NSNumber { return v.int64Value }
        if let v = value as? String { return Int64(v) }
        return nil
    }
}
