import Foundation

class AlarmStore {
    private let defaults = UserDefaults.standard

    func loadAll() -> [String: AlarmRecord] {
        guard let raw = defaults.dictionary(forKey: AlarmConstants.defaultsStoreKey) else {
            return [:]
        }
        var store: [String: AlarmRecord] = [:]
        for (key, value) in raw {
            if let dict = value as? [String: Any], let record = AlarmRecord.fromMap(dict) {
                store[key] = record
            }
        }
        return store
    }

    func saveAll(_ store: [String: AlarmRecord]) {
        var raw: [String: [String: Any]] = [:]
        for (key, record) in store {
            raw[key] = record.toMap()
        }
        let sanitized = Sanitizer.sanitize(raw) as? [String: Any] ?? [:]
        defaults.set(sanitized, forKey: AlarmConstants.defaultsStoreKey)
    }

    func getRecord(for id: String) -> AlarmRecord? {
        return loadAll()[id]
    }

    func upsertRecord(_ record: AlarmRecord) {
        var store = loadAll()
        store[record.id] = record
        saveAll(store)
    }

    func deleteRecord(for id: String) {
        var store = loadAll()
        store.removeValue(forKey: id)
        saveAll(store)
    }

    func setLaunchAlarmId(_ id: String) {
        defaults.set(id, forKey: AlarmConstants.defaultsLaunchAlarmIdKey)
    }

    func getLaunchAlarmId() -> String? {
        let id = defaults.string(forKey: AlarmConstants.defaultsLaunchAlarmIdKey)
        defaults.removeObject(forKey: AlarmConstants.defaultsLaunchAlarmIdKey)
        return id
    }

    func setPendingNotificationResponse(_ response: [String: Any]) {
        let sanitized = Sanitizer.sanitize(response) as? [String: Any] ?? [:]
        defaults.set(sanitized, forKey: AlarmConstants.defaultsPendingNotificationResponseKey)
    }

    func getPendingNotificationResponse() -> [String: Any]? {
        let pending = defaults.dictionary(forKey: AlarmConstants.defaultsPendingNotificationResponseKey)
        defaults.removeObject(forKey: AlarmConstants.defaultsPendingNotificationResponseKey)
        return pending
    }
}
