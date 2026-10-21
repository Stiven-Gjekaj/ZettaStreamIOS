import Foundation

/// The free space that a torrent needs on the device. The engine keeps the part of the
/// file that played until the torrent stops, so a long video can fill a small device.
public enum TorrentSpace {
    /// A torrent starts only with this much free space: 1 GB.
    public static let toStart: Int64 = 1 << 30
    /// A torrent that plays stops when the free space falls below this: 300 MB.
    public static let toContinue: Int64 = 300 << 20

    public static func canStart(free: Int64?) -> Bool {
        free.map { $0 >= toStart } ?? true
    }

    public static func canContinue(free: Int64?) -> Bool {
        free.map { $0 >= toContinue } ?? true
    }

    /// The free space of the volume of `folder` for important data, or nil when the system does not say.
    public static func free(at folder: URL) -> Int64? {
        let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
