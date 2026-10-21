import Network
import UIKit

/// Tells the app when the network comes back and when the app comes to the front again.
/// Then the addons and the playlists that did not answer try again, as on Android.
@MainActor
final class NetworkWatch {
    private let monitor = NWPathMonitor()
    private var online = true
    private var observer: NSObjectProtocol?

    func start(_ onReturn: @escaping @MainActor () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            let up = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let back = up && !self.online
                self.online = up
                if back { onReturn() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "io.github.stivengjekaj.zettastream.network"))
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { onReturn() }
        }
    }
}
