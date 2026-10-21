import zlib
import Foundation

public struct GzipError: Error, Equatable, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}

/// Opens a gzip file. A playlist or a guide is often a `.gz` file, and the
/// server does not always say so. Foundation has no gzip decoder, so this uses
/// the zlib of the system.
public enum Gzip {
    /// True when the data starts with the two bytes of a gzip file.
    public static func isGzip(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0x1f && data[data.startIndex + 1] == 0x8b
    }

    /// Opens the data when it is a gzip file. Other data comes back as it is.
    public static func openIfGzip(_ data: Data) throws -> Data {
        isGzip(data) ? try decode(data) : data
    }

    /// Opens a gzip file. A file can hold more than one member, one after the
    /// other. Bytes after the last member that are not a gzip member are left out.
    public static func decode(_ data: Data) throws -> Data {
        var stream = z_stream()
        // 15 is the largest window, and 16 more tells zlib to read the gzip header and its check sum.
        guard inflateInit2_(&stream, 15 + 16, zlibVersion(), Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw GzipError(message: "The gzip decoder does not start")
        }
        defer { inflateEnd(&stream) }

        let chunk = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunk)
        var output = Data()
        var input = [UInt8](data)
        let count = input.count
        try input.withUnsafeMutableBufferPointer { source in
            stream.next_in = source.baseAddress
            stream.avail_in = uInt(count)
            while true {
                let status = buffer.withUnsafeMutableBufferPointer { target -> Int32 in
                    stream.next_out = target.baseAddress
                    stream.avail_out = uInt(chunk)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                output.append(contentsOf: buffer[0..<(chunk - Int(stream.avail_out))])
                switch status {
                case Z_STREAM_END:
                    let rest = Int(stream.avail_in)
                    let next = count - rest
                    guard rest >= 2, source[next] == 0x1f, source[next + 1] == 0x8b else { return }
                    inflateReset(&stream)
                case Z_OK: continue
                case Z_BUF_ERROR where stream.avail_in == 0:
                    throw GzipError(message: "The gzip data has no end")
                default:
                    throw GzipError(message: "The gzip data is not correct")
                }
            }
        }
        return output
    }
}
