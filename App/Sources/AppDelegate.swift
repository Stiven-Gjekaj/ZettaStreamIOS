import UIKit

/// Gives the orientations that the app allows now. The player locks the screen to landscape.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

/// The orientations of the app. Each screen allows all of them, except the player.
@MainActor
enum OrientationLock {
    static var defaultMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    private(set) static var mask: UIInterfaceOrientationMask = defaultMask

    /// Allows only `mask`, and turns the screen when it shows another orientation.
    static func lock(_ mask: UIInterfaceOrientationMask) {
        self.mask = mask
        update(prefer: mask)
    }

    /// Allows all orientations again. A phone goes back to portrait.
    static func unlock() {
        mask = defaultMask
        update(prefer: UIDevice.current.userInterfaceIdiom == .pad ? defaultMask : .portrait)
    }

    private static func update(prefer: UIInterfaceOrientationMask) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            // A window in Split View or Stage Manager cannot turn. That is not a fault.
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: prefer)) { _ in }
        }
    }
}
