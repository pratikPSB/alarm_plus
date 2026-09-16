import Foundation

enum Sanitizer {
    static func sanitize(_ value: Any) -> Any? {
        if value is NSNull {
            return nil
        } else if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                if let sanitized = sanitize(val) {
                    result[key] = sanitized
                }
            }
            return result
        } else if let array = value as? [Any] {
            return array.compactMap { sanitize($0) }
        }
        return value
    }
}
