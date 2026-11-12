import UIKit
import Capacitor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = GymSmithViewController()
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }
}

// MARK: - GymSmith's own native code

/// The Capacitor web view, plus GymSmith's own plugin.
class GymSmithViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(ICloudBackupPlugin())
    }
}

/// Automatic backups to the person's own iCloud Drive (Files app > iCloud Drive > GymSmith).
/// The developer never sees these files: they live in the user's iCloud account.
@objc(ICloudBackupPlugin)
class ICloudBackupPlugin: CAPPlugin, CAPBridgedPlugin {
    let identifier = "ICloudBackupPlugin"
    let jsName = "ICloudBackup"
    let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "write", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "list", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "read", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "remove", returnType: CAPPluginReturnPromise)
    ]
    private let containerId = "iCloud.com.gymsmith.app"
    private let queue = DispatchQueue(label: "app.gymsmith.icloud", qos: .utility)

    /// The Documents folder of GymSmith's iCloud container, or nil when the person isn't signed in to iCloud
    /// or has turned iCloud Drive off for GymSmith. Must not be called on the main thread.
    private func folder() -> URL? {
        guard FileManager.default.ubiquityIdentityToken != nil,
              let base = FileManager.default.url(forUbiquityContainerIdentifier: containerId) else { return nil }
        let docs = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    /// Only plain backup file names, so nothing can reach outside the folder.
    private func safeName(_ name: String?) -> String? {
        guard let n = name, n.range(of: "^[A-Za-z0-9._-]{1,80}\\.json$", options: .regularExpression) != nil else { return nil }
        return n
    }

    @objc func status(_ call: CAPPluginCall) {
        queue.async { call.resolve(["available": self.folder() != nil]) }
    }

    @objc func write(_ call: CAPPluginCall) {
        guard let name = safeName(call.getString("name")), let text = call.getString("data") else { call.reject("Bad backup name"); return }
        queue.async {
            guard let dir = self.folder() else { call.reject("iCloud Drive isn't available", "UNAVAILABLE"); return }
            let url = dir.appendingPathComponent(name)
            var coordError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { target in
                do { try text.write(to: target, atomically: true, encoding: .utf8) } catch { writeError = error }
            }
            if let e = coordError ?? writeError { call.reject(e.localizedDescription) } else { call.resolve(["name": name]) }
        }
    }

    @objc func list(_ call: CAPPluginCall) {
        queue.async {
            guard let dir = self.folder() else { call.resolve(["available": false, "files": []]); return }
            let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
            let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys, options: [])) ?? []
            var files: [[String: Any]] = []
            for url in urls {
                var name = url.lastPathComponent
                // a backup that's only in iCloud so far shows up as ".name.json.icloud"
                if name.hasPrefix(".") && name.hasSuffix(".icloud") { name = String(name.dropFirst().dropLast(7)) }
                guard name.hasSuffix(".json") else { continue }
                let values = try? url.resourceValues(forKeys: Set(keys))
                files.append([
                    "name": name,
                    "modified": (values?.contentModificationDate?.timeIntervalSince1970 ?? 0) * 1000,
                    "size": values?.fileSize ?? 0
                ])
            }
            call.resolve(["available": true, "files": files])
        }
    }

    @objc func read(_ call: CAPPluginCall) {
        guard let name = safeName(call.getString("name")) else { call.reject("Bad backup name"); return }
        queue.async {
            guard let dir = self.folder() else { call.reject("iCloud Drive isn't available", "UNAVAILABLE"); return }
            let url = dir.appendingPathComponent(name)
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            var coordError: NSError?
            var readError: Error?
            var text: String?
            // a coordinated read waits for iCloud to download the file if needed
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { target in
                do { text = try String(contentsOf: target, encoding: .utf8) } catch { readError = error }
            }
            if let t = text { call.resolve(["data": t]) }
            else { call.reject((coordError ?? readError)?.localizedDescription ?? "Couldn't read that backup", "READ") }
        }
    }

    @objc func remove(_ call: CAPPluginCall) {
        guard let name = safeName(call.getString("name")) else { call.reject("Bad backup name"); return }
        queue.async {
            guard let dir = self.folder() else { call.reject("iCloud Drive isn't available", "UNAVAILABLE"); return }
            let url = dir.appendingPathComponent(name)
            var coordError: NSError?
            var removeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { target in
                do { try FileManager.default.removeItem(at: target) } catch { removeError = error }
            }
            if let e = coordError ?? removeError { call.reject(e.localizedDescription) } else { call.resolve() }
        }
    }
}
