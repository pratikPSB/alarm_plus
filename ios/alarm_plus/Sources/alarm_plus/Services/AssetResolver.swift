import Foundation
import UserNotifications
import Flutter

class AssetResolver {
    private weak var registrar: FlutterPluginRegistrar?

    init(registrar: FlutterPluginRegistrar?) {
        self.registrar = registrar
    }

    func resolveSoundAsset(_ assetPath: String?) -> String? {
        guard let assetPath = assetPath, !assetPath.isEmpty else { return nil }
        let fileName = URL(fileURLWithPath: assetPath).lastPathComponent
        let fileManager = FileManager.default
        guard let libraryUrl = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let soundsUrl = libraryUrl.appendingPathComponent("Sounds")
        let destinationUrl = soundsUrl.appendingPathComponent(fileName)

        if !fileManager.fileExists(atPath: destinationUrl.path) {
            guard let key = registrar?.lookupKey(forAsset: assetPath),
                  let sourcePath = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
            do {
                try fileManager.createDirectory(at: soundsUrl, withIntermediateDirectories: true, attributes: nil)
                try fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: destinationUrl)
            } catch {
                return nil
            }
        }
        return fileName
    }

    func resolveImageAsset(_ assetPath: String?) -> UNNotificationAttachment? {
        guard let assetPath = assetPath, !assetPath.isEmpty else { return nil }
        guard let key = registrar?.lookupKey(forAsset: assetPath),
              let sourcePath = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
        let url = URL(fileURLWithPath: sourcePath)
        do {
            return try UNNotificationAttachment(identifier: UUID().uuidString, url: url, options: nil)
        } catch {
            return nil
        }
    }

    func resolveImageUrl(_ urlString: String?, completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        let task = URLSession.shared.downloadTask(with: url) { (location, response, error) in
            guard let location = location else {
                completion(nil)
                return
            }
            let tmpDir = NSTemporaryDirectory()
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let fileName = "alarm_plus_img_\(UUID().uuidString).\(ext)"
            let tmpFile = (tmpDir as NSString).appendingPathComponent(fileName)
            let tmpUrl = URL(fileURLWithPath: tmpFile)
            do {
                if FileManager.default.fileExists(atPath: tmpFile) {
                    try FileManager.default.removeItem(at: tmpUrl)
                }
                try FileManager.default.moveItem(at: location, to: tmpUrl)
                let attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: tmpUrl, options: nil)
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    func getAudioUrl(for assetPath: String?) -> URL? {
        if let asset = assetPath, let key = registrar?.lookupKey(forAsset: asset), let path = Bundle.main.path(forResource: key, ofType: nil) {
            return URL(fileURLWithPath: path)
        }
        return Bundle.main.url(forResource: "alarm", withExtension: "mp3")
    }
}
