import SwiftUI
import UniformTypeIdentifiers

/// A backup as a JSON file, for the file exporter.
struct SettingsBackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Reads the text of a file that the viewer chose in the file importer.
enum SettingsFileReader {
    static func text(of url: URL) throws -> String {
        // A file from the Files app is outside the sandbox of the app, so the app asks for access first.
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }
}
