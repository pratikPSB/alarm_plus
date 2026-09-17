import Foundation
import Flutter
import SwiftUI

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
#endif

final class PluginAlarmManager: NotificationServiceDelegate {
    private let store: AlarmStore
    private let notificationService: NotificationService
    private let audioService: AudioService
    private let assetResolver: AssetResolver

    var eventSink: FlutterEventSink?
    var methodChannel: FlutterMethodChannel?

#if canImport(AlarmKit)
    private var alarmKitTask: Task<Void, Never>?
#endif

    init(registrar: FlutterPluginRegistrar) {
        store = AlarmStore()
        assetResolver = AssetResolver(registrar: registrar)
        audioService = AudioService(assetResolver: assetResolver)
        notificationService = NotificationService(assetResolver: assetResolver)
        notificationService.delegate = self

#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            startAlarmKitUpdates()
        }
#endif
    }

    deinit {
#if canImport(AlarmKit)
        alarmKitTask?.cancel()
#endif
    }

    // MARK: - API handlers

    func triggerNow(
        data: [String: Any],
        settings: [String: Any]?,
        result: @escaping FlutterResult
    ) {
        let nowMs = currentTimeMillis()
        let id = (data["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? "trigger_\(UUID().uuidString)"
        let record = makeRecord(
            id: id,
            scheduledTimeUtcMs: nowMs,
            payloadJson: jsonString(data),
            settings: settings
        )

        // AlarmKit rejects a fire date in the past. One second remains effectively
        // immediate while giving the system time to register the alarm.
        schedule(record: record, fireDate: Date().addingTimeInterval(1), result: result)
    }

    func schedule(args: [String: Any], result: @escaping FlutterResult) {
        guard
            let id = args["id"] as? String,
            !id.isEmpty,
            let timeUtcMs = args["timeUtcMs"] as? NSNumber
        else {
            result(FlutterError(code: "ERR_INVALID_ARGS", message: "Missing id/time", details: nil))
            return
        }

        let scheduledTimeUtcMs = timeUtcMs.int64Value
        let record = makeRecord(
            id: id,
            scheduledTimeUtcMs: scheduledTimeUtcMs,
            scheduledTimeLocalIso: args["timeLocalIso"] as? String,
            payloadJson: jsonString(args["data"] as? [String: Any] ?? [:]),
            settings: args["notificationSettings"] as? [String: Any]
        )
        let fireDate = Date(timeIntervalSince1970: TimeInterval(scheduledTimeUtcMs) / 1000)

        schedule(record: record, fireDate: fireDate, result: result)
    }

    func cancel(id: String, result: @escaping FlutterResult) {
        let record = store.getRecord(for: id)

#if canImport(AlarmKit)
        if #available(iOS 26.0, *), let alarmID = record.flatMap(alarmKitID(for:)) {
            try? AlarmKit.AlarmManager.shared.cancel(id: alarmID)
        }
#endif

        audioService.cancelAudioTimer(id: id)
        notificationService.cancelNotification(for: id)
        if var record {
            record.status = "canceled"
            record.updatedAtMs = currentTimeMillis()
            store.upsertRecord(record)
        }
        result(nil)
    }

    func delete(id: String, result: @escaping FlutterResult) {
        let record = store.getRecord(for: id)

#if canImport(AlarmKit)
        if #available(iOS 26.0, *), let alarmID = record.flatMap(alarmKitID(for:)) {
            try? AlarmKit.AlarmManager.shared.cancel(id: alarmID)
        }
#endif

        audioService.cancelAudioTimer(id: id)
        notificationService.cancelNotification(for: id)
        store.deleteRecord(for: id)
        result(nil)
    }

    func stop(result: @escaping FlutterResult) {
        var allRecords = store.loadAll()

        for (id, var record) in allRecords where record.status == "triggered" {
#if canImport(AlarmKit)
            if #available(iOS 26.0, *), let alarmID = alarmKitID(for: record) {
                try? AlarmKit.AlarmManager.shared.stop(id: alarmID)
            }
#endif

            record.status = "stopped"
            record.updatedAtMs = currentTimeMillis()
            allRecords[id] = record
            emitEvent(AlarmEvent(type: "stopped", id: id, alarm: record))
        }

        store.saveAll(allRecords)
        audioService.stopRinging()
        notificationService.removeAllDelivered()
        result(nil)
    }

    func snooze(id: String, minutes: Int, result: @escaping FlutterResult) {
        guard var record = store.getRecord(for: id) else {
            result(FlutterError(code: "ERR_ALARM_NOT_FOUND", message: "Alarm not found", details: nil))
            return
        }

        let snoozeMinutes = max(minutes, 1)
        let nextTime = currentTimeMillis() + Int64(snoozeMinutes) * 60_000
        record.scheduledTimeUtcMs = nextTime
        record.scheduledTimeLocalIso = isoFromMillis(nextTime)
        record.status = "snoozed"
        record.updatedAtMs = currentTimeMillis()
        record.platformMeta["snoozeMinutes"] = snoozeMinutes
        let fireDate = Date(timeIntervalSince1970: TimeInterval(nextTime) / 1000)

#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { [weak self] in
                guard let self else { return }
                if let alarmID = self.alarmKitID(for: record) {
                    try? AlarmKit.AlarmManager.shared.stop(id: alarmID)
                }

                do {
                    let scheduledRecord = try await self.scheduleWithAlarmKit(
                        record: record,
                        fireDate: fireDate
                    )
                    self.store.upsertRecord(scheduledRecord)
                    self.audioService.stopRinging()
                    self.emitEvent(
                        AlarmEvent(
                            type: "snoozed",
                            id: id,
                            alarm: scheduledRecord,
                            meta: ["minutes": snoozeMinutes]
                        )
                    )
                    result(nil)
                } catch {
                    self.reportScheduleFailure(record: record, error: error, result: result)
                }
            }
            return
        }
#endif

        store.upsertRecord(record)
        notificationService.scheduleNotification(record: record, fireDate: fireDate) { [weak self] error in
            if let error {
                self?.reportLegacyScheduleFailure(record: record, error: error)
            }
        }
        audioService.stopRinging()
        audioService.scheduleAudioTimer(id: id, fireDate: fireDate) { [weak self] in
            self?.audioService.startRinging(record: record)
        }
        emitEvent(AlarmEvent(type: "snoozed", id: id, alarm: record, meta: ["minutes": snoozeMinutes]))
        result(nil)
    }

    func getAll(result: @escaping FlutterResult) {
        let records = store.loadAll().values
            .map { $0.toMap() }
            .sorted {
                ($0["scheduledTimeUtcMs"] as? Int64 ?? 0)
                    < ($1["scheduledTimeUtcMs"] as? Int64 ?? 0)
            }
        result(records)
    }

    func getLaunchAlarm(result: @escaping FlutterResult) {
        guard let id = store.getLaunchAlarmId() else {
            result(nil)
            return
        }
        result(store.getRecord(for: id)?.toMap())
    }

    func getPermissionStatus(result: @escaping FlutterResult) {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            result(alarmKitPermissionStatus().toMap())
            return
        }
#endif

        notificationService.getPermissionStatus { status in
            result(status.toMap())
        }
    }

    func requestPermissions(result: @escaping FlutterResult) {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { [weak self] in
                guard let self else { return }
                do {
                    _ = try await AlarmKit.AlarmManager.shared.requestAuthorization()
                    let status = self.alarmKitPermissionStatus()
                    self.emitEvent(AlarmEvent(type: "permissionChanged", meta: status.toMap()))
                    result(status.toMap())
                } catch {
                    result(
                        FlutterError(
                            code: "ERR_PERMISSION_REQUEST_FAILED",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
            return
        }
#endif

        notificationService.requestPermissions { [weak self] status in
            self?.emitEvent(AlarmEvent(type: "permissionChanged", meta: status.toMap()))
            result(status.toMap())
        }
    }

    func getLastNotificationResponse(result: @escaping FlutterResult) {
        result(store.getPendingNotificationResponse())
    }

    // MARK: - NotificationServiceDelegate

    func onAlarmTriggered(id: String) {
        guard var record = store.getRecord(for: id) else { return }
        let now = currentTimeMillis()
        let drift = now - record.scheduledTimeUtcMs

        record.status = "triggered"
        record.updatedAtMs = now
        record.lastTriggeredAtMs = now
        record.lastDriftMs = drift
        store.upsertRecord(record)
        emitEvent(AlarmEvent(type: "triggered", id: id, alarm: record, meta: ["driftMs": drift]))

        audioService.startRinging(record: record)
    }

    func onNotificationResponse(alarmId: String, actionId: String?, payload: String?, type: Int) {
        store.setLaunchAlarmId(alarmId)

        let responseMap: [String: Any] = [
            "notificationId": alarmId.hashValue,
            "alarmId": alarmId,
            "actionId": actionId ?? "",
            "payload": payload ?? "",
            "notificationResponseType": type,
            "data": ["alarmId": alarmId]
        ]
        store.setPendingNotificationResponse(responseMap)
        runOnMain { [weak self] in
            self?.methodChannel?.invokeMethod("didReceiveNotificationResponse", arguments: responseMap)
        }

        if actionId == AlarmConstants.actionStopId {
            stop(result: { _ in })
        } else if actionId == AlarmConstants.actionSnoozeId {
            snooze(id: alarmId, minutes: AlarmConstants.defaultSnoozeMinutes, result: { _ in })
        }
    }

    // MARK: - Shared scheduling

    private func makeRecord(
        id: String,
        scheduledTimeUtcMs: Int64,
        scheduledTimeLocalIso: String? = nil,
        payloadJson: String?,
        settings: [String: Any]?
    ) -> AlarmRecord {
        let existing = store.getRecord(for: id)
        var platformMeta: [String: Any] = [:]
        if let alarmKitID = existing?.platformMeta["alarmKitId"] {
            platformMeta["alarmKitId"] = alarmKitID
        }
        if let settings {
            platformMeta["notificationSettings"] = settings
        }

        return AlarmRecord(
            id: id,
            scheduledTimeUtcMs: scheduledTimeUtcMs,
            scheduledTimeLocalIso: scheduledTimeLocalIso ?? isoFromMillis(scheduledTimeUtcMs),
            payloadJson: payloadJson,
            status: "scheduled",
            createdAtMs: existing?.createdAtMs ?? currentTimeMillis(),
            platformMeta: platformMeta
        )
    }

    private func schedule(record: AlarmRecord, fireDate: Date, result: @escaping FlutterResult) {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let scheduledRecord = try await self.scheduleWithAlarmKit(
                        record: record,
                        fireDate: fireDate
                    )
                    self.store.upsertRecord(scheduledRecord)
                    result(nil)
                } catch {
                    self.reportScheduleFailure(record: record, error: error, result: result)
                }
            }
            return
        }
#endif

        audioService.cancelAudioTimer(id: record.id)
        notificationService.cancelNotification(for: record.id)
        store.upsertRecord(record)
        notificationService.scheduleNotification(record: record, fireDate: fireDate) { [weak self] error in
            if let error {
                self?.reportLegacyScheduleFailure(record: record, error: error)
            }
        }
        audioService.scheduleAudioTimer(id: record.id, fireDate: fireDate) { [weak self] in
            self?.audioService.startRinging(record: record)
        }
        result(nil)
    }

    private func reportScheduleFailure(
        record: AlarmRecord,
        error: Error,
        result: @escaping FlutterResult
    ) {
        var errorRecord = record
        errorRecord.status = "error"
        errorRecord.updatedAtMs = currentTimeMillis()
        store.upsertRecord(errorRecord)
        emitEvent(
            AlarmEvent(
                type: "error",
                id: record.id,
                alarm: errorRecord,
                errorCode: "ERR_SCHEDULE_FAILED",
                errorMessage: error.localizedDescription
            )
        )
        result(
            FlutterError(
                code: "ERR_SCHEDULE_FAILED",
                message: error.localizedDescription,
                details: nil
            )
        )
    }

    private func reportLegacyScheduleFailure(record: AlarmRecord, error: Error) {
        var errorRecord = record
        errorRecord.status = "error"
        errorRecord.updatedAtMs = currentTimeMillis()
        store.upsertRecord(errorRecord)
        emitEvent(
            AlarmEvent(
                type: "error",
                id: record.id,
                alarm: errorRecord,
                errorCode: "ERR_SCHEDULE_FAILED",
                errorMessage: error.localizedDescription
            )
        )
    }

    // MARK: - AlarmKit (iOS 26+)

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func scheduleWithAlarmKit(record: AlarmRecord, fireDate: Date) async throws -> AlarmRecord {
        guard AlarmKit.AlarmManager.shared.authorizationState == .authorized else {
            throw AlarmKitSchedulingError.notAuthorized
        }

        var record = record
        let alarmID = alarmKitID(for: record) ?? UUID()
        record.platformMeta["alarmKitId"] = alarmID.uuidString

        // Replacing an alarm ID must first remove its prior system schedule.
        if store.getRecord(for: record.id) != nil {
            try? AlarmKit.AlarmManager.shared.cancel(id: alarmID)
        }

        let settings = record.platformMeta["notificationSettings"] as? [String: Any]
        let title = settings?["title"] as? String ?? "Alarm"
        let alert: AlarmKit.AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmKit.AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title)
            )
        } else {
            alert = AlarmKit.AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: AlarmKit.AlarmButton(
                    text: "Stop",
                    textColor: .white,
                    systemImageName: "stop.fill"
                )
            )
        }
        let attributes = AlarmKit.AlarmAttributes<AlarmKitMetadata>(
            presentation: AlarmKit.AlarmPresentation(alert: alert),
            metadata: AlarmKitMetadata(alarmID: record.id),
            tintColor: .blue
        )
        let configuration = AlarmKit.AlarmManager.AlarmConfiguration<AlarmKitMetadata>.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes,
            sound: alarmKitSound(from: settings)
        )

        _ = try await AlarmKit.AlarmManager.shared.schedule(
            id: alarmID,
            configuration: configuration
        )
        return record
    }

    @available(iOS 26.0, *)
    private func alarmKitSound(from settings: [String: Any]?) -> ActivityKit.AlertConfiguration.AlertSound {
        guard
            let soundAsset = settings?["soundAsset"] as? String,
            let soundName = assetResolver.resolveSoundAsset(soundAsset)
        else {
            return .default
        }
        return .named(soundName)
    }

    @available(iOS 26.0, *)
    private func startAlarmKitUpdates() {
        alarmKitTask = Task { [weak self] in
            var previousStates: [UUID: AlarmKit.Alarm.State] = [:]

            for await alarms in AlarmKit.AlarmManager.shared.alarmUpdates {
                guard let self, !Task.isCancelled else { break }
                let currentIDs = Set(alarms.map(\.id))

                for (alarmID, state) in previousStates where !currentIDs.contains(alarmID) {
                    if state == .alerting {
                        self.markAlarmKitStopped(alarmID: alarmID)
                    }
                }

                for alarm in alarms {
                    self.syncAlarmKitState(alarm)
                }
                previousStates = Dictionary(uniqueKeysWithValues: alarms.map { ($0.id, $0.state) })
            }
        }
    }

    @available(iOS 26.0, *)
    private func syncAlarmKitState(_ alarm: AlarmKit.Alarm) {
        guard var record = record(forAlarmKitID: alarm.id) else { return }

        switch alarm.state {
        case .alerting:
            guard record.status != "triggered" else { return }
            let now = currentTimeMillis()
            let drift = now - record.scheduledTimeUtcMs
            record.status = "triggered"
            record.updatedAtMs = now
            record.lastTriggeredAtMs = now
            record.lastDriftMs = drift
            store.upsertRecord(record)
            store.setLaunchAlarmId(record.id)
            emitEvent(
                AlarmEvent(
                    type: "triggered",
                    id: record.id,
                    alarm: record,
                    meta: ["driftMs": drift]
                )
            )
        case .scheduled, .countdown, .paused:
            break
        @unknown default:
            break
        }
    }

    @available(iOS 26.0, *)
    private func markAlarmKitStopped(alarmID: UUID) {
        guard var record = record(forAlarmKitID: alarmID), record.status == "triggered" else {
            return
        }
        record.status = "stopped"
        record.updatedAtMs = currentTimeMillis()
        store.upsertRecord(record)
        emitEvent(AlarmEvent(type: "stopped", id: record.id, alarm: record))
    }

    @available(iOS 26.0, *)
    private func alarmKitPermissionStatus() -> PermissionStatus {
        let authorization = AlarmKit.AlarmManager.shared.authorizationState
        return PermissionStatus(
            notificationsGranted: authorization == .authorized,
            criticalAlertsEligible: false,
            platformMeta: ["alarmKitAuthorization": alarmKitAuthorizationName(authorization)]
        )
    }

    @available(iOS 26.0, *)
    private func alarmKitAuthorizationName(_ authorization: AlarmKit.AlarmManager.AuthorizationState) -> String {
        switch authorization {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "unknown"
        }
    }

    @available(iOS 26.0, *)
    private func alarmKitID(for record: AlarmRecord) -> UUID? {
        guard let value = record.platformMeta["alarmKitId"] as? String else { return nil }
        return UUID(uuidString: value)
    }

    @available(iOS 26.0, *)
    private func record(forAlarmKitID alarmID: UUID) -> AlarmRecord? {
        store.loadAll().values.first { alarmKitID(for: $0) == alarmID }
    }
#endif

    // MARK: - Helpers

    private func emitEvent(_ event: AlarmEvent) {
        let payload = event.toMap()
        runOnMain { [weak self] in
            self?.eventSink?(payload)
        }
    }

    private func currentTimeMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func isoFromMillis(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func jsonString(_ map: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(map) else { return nil }
        let data = try? JSONSerialization.data(withJSONObject: map, options: [])
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }
}

#if canImport(AlarmKit)
private enum AlarmKitSchedulingError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "AlarmKit permission has not been granted"
        }
    }
}
#endif
