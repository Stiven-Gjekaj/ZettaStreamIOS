import Foundation

/// One stream in the list, with the addon that gave it and what its text says.
public struct ListedStream: Hashable, Sendable {
    public var addon: Addon
    public var stream: AddonStream
    public var info: StreamInfo

    /// Reads the info from the text of the stream when the caller does not give it.
    public init(addon: Addon, stream: AddonStream, info: StreamInfo? = nil) {
        self.addon = addon
        self.stream = stream
        self.info = info ?? StreamInfo(stream)
    }

    /// The streams of one addon, in the order of the addon.
    public static func list(_ addon: Addon, _ streams: [AddonStream]) -> [ListedStream] {
        streams.map { ListedStream(addon: addon, stream: $0) }
    }
}
