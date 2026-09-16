import Foundation

struct AlarmEvent {
    let type: String
    let atMs: Int64
    let id: String?
    let alarm: AlarmRecord?
    let errorCode: String?
    let errorMessage: String?
    let meta: [String: Any]

    init(
        type: String,
        id: String? = nil,
        alarm: AlarmRecord? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        meta: [String: Any] = [:]
    ) {
        self.type = type
        self.atMs = Int64(Date().timeIntervalSince1970 * 1000)
        self.id = id
        self.alarm = alarm
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.meta = meta
    }

    func toMap() -> [String: Any] {
        return [
            "type": type,
            "atMs": atMs,
            "id": id as Any,
            "alarm": alarm?.toMap() as Any,
            "errorCode": errorCode as Any,
            "errorMessage": errorMessage as Any,
            "meta": meta
        ]
    }
}
