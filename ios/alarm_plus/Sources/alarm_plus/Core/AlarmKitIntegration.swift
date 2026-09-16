#if canImport(AlarmKit)
import AlarmKit
import Foundation

@available(iOS 26.0, *)
struct AlarmKitMetadata: AlarmMetadata {
    let alarmID: String
}
#endif
