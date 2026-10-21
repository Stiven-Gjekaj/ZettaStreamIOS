import Foundation
import Testing
@testable import ZettaCore

struct GzipTests {
    // The output of `printf '#EXTM3U\n' | gzip -n`.
    private let playlist: [UInt8] = [
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x53, 0x76,
        0x8d, 0x08, 0xf1, 0x35, 0x0e, 0xe5, 0x02, 0x00, 0xb5, 0x98, 0xec, 0x41,
        0x08, 0x00, 0x00, 0x00,
    ]

    // The output of `printf 'two\n' | gzip -n`.
    private let two: [UInt8] = [
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x2b, 0x29,
        0xcf, 0xe7, 0x02, 0x00, 0x74, 0x08, 0x17, 0x96, 0x04, 0x00, 0x00, 0x00,
    ]

    private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

    @Test func opensAGzipFile() throws {
        #expect(Gzip.isGzip(Data(playlist)))
        #expect(text(try Gzip.openIfGzip(Data(playlist))) == "#EXTM3U\n")
    }

    @Test func plainDataComesBackAsItIs() throws {
        let plain = Data("#EXTM3U\n".utf8)
        #expect(!Gzip.isGzip(plain))
        #expect(try Gzip.openIfGzip(plain) == plain)
        #expect(try Gzip.openIfGzip(Data()) == Data())
    }

    @Test func readsAHeaderWithAFileName() throws {
        // The output of `gzip -c a.txt`, where the file holds `a.xml` and a new line.
        let named: [UInt8] = [
            0x1f, 0x8b, 0x08, 0x08, 0x65, 0xb5, 0xd8, 0x6a, 0x00, 0x03, 0x61, 0x2e,
            0x74, 0x78, 0x74, 0x00, 0x4b, 0xd4, 0xab, 0xc8, 0xcd, 0xe1, 0x02, 0x00,
            0x8c, 0xf1, 0x82, 0xcb, 0x06, 0x00, 0x00, 0x00,
        ]
        #expect(text(try Gzip.decode(Data(named))) == "a.xml\n")
    }

    @Test func readsMembersOneAfterTheOther() throws {
        #expect(text(try Gzip.decode(Data(playlist + two))) == "#EXTM3U\ntwo\n")
        #expect(text(try Gzip.decode(Data(playlist + [0x0a, 0x0a]))) == "#EXTM3U\n")
    }

    @Test func opensAFileThatIsLargerThanOneBuffer() throws {
        // The output of `yes line | head -40000 | gzip -n -9`. It opens to 200000 bytes.
        let start: [UInt8] = [
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x03, 0xed, 0xc4,
            0xa1, 0x0d, 0x00, 0x00, 0x08, 0x03, 0x30, 0xcf, 0x9f, 0x08, 0x92, 0x85,
            0xff, 0x25, 0x37, 0xe0, 0x5b, 0xd1, 0xcc, 0x76, 0x45,
        ]
        let middle = [[UInt8]](repeating: [0x92, 0x24, 0x49], count: 96).flatMap { $0 }
        let end: [UInt8] = [0x92, 0x24, 0x7d, 0x3a, 0x33, 0x78, 0x1f, 0x71, 0x40, 0x0d, 0x03, 0x00]
        let opened = try Gzip.decode(Data(start + middle + end))
        #expect(opened.count == 200_000)
        #expect(text(opened) == String(repeating: "line\n", count: 40_000))
    }

    @Test func aDamagedFileThrows() {
        var wrongSum = playlist
        wrongSum[20] ^= 0xff
        #expect(throws: GzipError.self) { try Gzip.decode(Data(wrongSum)) }
        #expect(throws: GzipError.self) { try Gzip.decode(Data(playlist.prefix(16))) }
        #expect(throws: GzipError.self) { try Gzip.decode(Data([0x1f, 0x8b, 0x08])) }
    }

    private func decodeFile(_ bytes: [UInt8]) throws -> Data {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("gzip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("in"), target = folder.appendingPathComponent("out")
        try Data(bytes).write(to: source)
        #expect(Gzip.isGzip(file: source) == Gzip.isGzip(Data(bytes)))
        try Gzip.decode(file: source, to: target)
        return try Data(contentsOf: target)
    }

    @Test func aFileOpensIntoAFileWithTwoMembersAndTrailingBytes() throws {
        #expect(text(try decodeFile(playlist)) == "#EXTM3U\n")
        #expect(text(try decodeFile(playlist + two)) == "#EXTM3U\ntwo\n")
        #expect(text(try decodeFile(playlist + [0x00, 0x00, 0x00])) == "#EXTM3U\n")
    }

    @Test func aCutFileThrows() {
        #expect(throws: GzipError.self) { try decodeFile(Array(playlist.prefix(15))) }
        #expect(throws: GzipError.self) { try decodeFile([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0xff, 0xff, 0xff]) }
    }

    @Test func aFileLargerThanOnePartOpensTheSameAsInMemory() throws {
        // Text that does not shrink much, so that both the input and the output need many parts.
        var generator = SystemRandomNumberGenerator()
        let original = Data((0..<3_000_000).map { _ in UInt8.random(in: 0x41...0x5a, using: &generator) })
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = ["-c", "-n"]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        let writer = Thread { input.fileHandleForWriting.write(original); try? input.fileHandleForWriting.close() }
        writer.start()
        let packed = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(packed.count > 512 * 1024)
        #expect(try decodeFile([UInt8](packed) + [UInt8](packed)) == original + original)
        #expect(try Gzip.decode(packed) == original)
    }
}
