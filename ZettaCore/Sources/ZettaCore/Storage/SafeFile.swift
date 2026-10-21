import Foundation

/// Writes a file through a temporary file, so that a stop during a write keeps
/// the old file. One write runs at a time, so two writes do not mix their bytes.
public final class SafeFile: @unchecked Sendable {
    public let file: URL
    private let lock = NSLock()

    public init(file: URL) {
        self.file = file
    }

    public func write(_ text: String) throws {
        try lock.withLock {
            // The folder of a new profile does not exist before its first write.
            let folder = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let temp = folder.appendingPathComponent(file.lastPathComponent + ".tmp")
            try Data(text.utf8).write(to: temp)
            // A rename in the same folder replaces the old file in one step.
            if rename(temp.path, file.path) != 0 {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: file.path])
            }
        }
    }
}
