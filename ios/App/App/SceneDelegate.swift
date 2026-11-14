import UIKit
import Capacitor
import StoreKit

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
        bridge?.registerPluginInstance(StorePlugin())
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

/// In-app purchases (StoreKit 2): the founding-member check, the free trial and the one-off unlock.
/// Apple handles every payment; GymSmith only learns which products this Apple ID owns.
@objc(StorePlugin)
class StorePlugin: CAPPlugin, CAPBridgedPlugin {
    let identifier = "StorePlugin"
    let jsName = "Store"
    let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "appInfo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "products", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "purchase", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "entitlements", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "restore", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "review", returnType: CAPPluginReturnPromise)
    ]
    private var updates: Task<Void, Never>?

    override func load() {
        // purchases finished outside the app (Ask to Buy, Family Sharing, a refund) arrive here
        updates = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                self?.notifyListeners("entitlementsChanged", data: [:])
            }
        }
    }

    deinit { updates?.cancel() }

    private static func ms(_ d: Date) -> Double { d.timeIntervalSince1970 * 1000 }

    /// When this Apple ID first got GymSmith (survives deleting and reinstalling the app).
    @objc func appInfo(_ call: CAPPluginCall) {
        Task {
            do {
                let result = try await AppTransaction.shared
                switch result {
                case .verified(let a):
                    call.resolve(["originalDate": Self.ms(a.originalPurchaseDate), "originalVersion": a.originalAppVersion,
                                  "environment": a.environment.rawValue, "verified": true])
                case .unverified(let a, _):
                    call.resolve(["originalDate": Self.ms(a.originalPurchaseDate), "originalVersion": a.originalAppVersion,
                                  "environment": a.environment.rawValue, "verified": false])
                }
            } catch {
                call.reject(error.localizedDescription, "APP_TRANSACTION")
            }
        }
    }

    @objc func products(_ call: CAPPluginCall) {
        let ids = call.getArray("ids", String.self) ?? []
        Task {
            do {
                let list = try await Product.products(for: ids)
                call.resolve(["products": list.map { ["id": $0.id, "price": $0.displayPrice, "name": $0.displayName] }])
            } catch {
                call.reject(error.localizedDescription, "PRODUCTS")
            }
        }
    }

    @objc func purchase(_ call: CAPPluginCall) {
        guard let id = call.getString("id") else { call.reject("No product"); return }
        Task {
            do {
                guard let product = try await Product.products(for: [id]).first else { call.reject("Product not found", "NOT_FOUND"); return }
                var result: Product.PurchaseResult?
                if #available(iOS 17.0, *) {
                    let scene = await MainActor.run { UIApplication.shared.connectedScenes.first as? UIWindowScene }
                    if let scene = scene { result = try await product.purchase(confirmIn: scene) }
                }
                if result == nil { result = try await product.purchase() }
                switch result! {
                case .success(let verification):
                    guard case .verified(let t) = verification else { call.reject("Apple couldn't verify the purchase", "UNVERIFIED"); return }
                    await t.finish()
                    call.resolve(["status": "purchased", "id": t.productID, "date": Self.ms(t.purchaseDate)])
                case .userCancelled:
                    call.resolve(["status": "cancelled"])
                case .pending:
                    call.resolve(["status": "pending"])
                @unknown default:
                    call.resolve(["status": "cancelled"])
                }
            } catch {
                call.reject(error.localizedDescription, "PURCHASE")
            }
        }
    }

    private func currentEntitlements() async -> [[String: Any]] {
        var out: [[String: Any]] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            out.append(["id": t.productID, "date": Self.ms(t.purchaseDate), "family": t.ownershipType == .familyShared])
        }
        return out
    }

    @objc func entitlements(_ call: CAPPluginCall) {
        Task { call.resolve(["items": await self.currentEntitlements()]) }
    }

    /// "Restore purchase": asks Apple to resend everything this Apple ID owns (may ask the person to sign in).
    @objc func restore(_ call: CAPPluginCall) {
        Task {
            do { try await AppStore.sync() } catch {
                if case StoreKitError.userCancelled = error { call.resolve(["status": "cancelled"]); return }
                call.reject(error.localizedDescription, "RESTORE"); return
            }
            call.resolve(["status": "ok", "items": await self.currentEntitlements()])
        }
    }

    /// Apple's own rating prompt. Apple decides whether it actually appears (at most 3 times a year).
    @objc func review(_ call: CAPPluginCall) {
        Task { @MainActor in
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
            call.resolve()
        }
    }
}
