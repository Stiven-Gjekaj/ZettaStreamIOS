import Foundation

/// One programme in the TV guide. Times are in milliseconds since 1970.
public struct Programme: Hashable, Sendable {
    public var channelId: String
    public var title: String
    public var start: Int64
    public var stop: Int64
    public var description: String?

    public init(channelId: String, title: String, start: Int64, stop: Int64, description: String? = nil) {
        self.channelId = channelId
        self.title = title
        self.start = start
        self.stop = stop
        self.description = description
    }
}

/// The programmes of each channel, in the order of their start times.
public struct Guide: Hashable, Sendable {
    private let byChannel: [String: [Programme]]
    // The keys of the guide for each short key, such as "cnnus@east" and "cnnus@west" for "cnnus".
    private let byShortKey: [String: [String]]

    public static let empty = Guide([:])

    /// The keys of `byChannel` are full keys, as `Xmltv.fullKey` makes them.
    init(_ byChannel: [String: [Programme]]) {
        self.byChannel = byChannel
        var groups: [String: [String]] = [:]
        for key in byChannel.keys.sorted() {
            groups[String(key.prefix { $0 != "@" }), default: []].append(key)
        }
        byShortKey = groups
    }

    /// The programmes of a channel. The same form, with its `@` part, comes first. Then a
    /// channel in another form gets the one feed with no `@` part, or else the first feed.
    /// Two feeds such as East and West never mix.
    public func programmes(_ channelId: String?) -> [Programme] {
        guard let channelId else { return [] }
        if let exact = byChannel[Xmltv.fullKey(channelId)] { return exact }
        let short = Xmltv.channelKey(channelId)
        guard let keys = byShortKey[short], let first = keys.first else { return [] }
        return byChannel[keys.first { $0 == short } ?? first] ?? []
    }

    /// Finds the programme that is on now and the one after it.
    public func nowAndNext(_ channelId: String?, now: Int64) -> (now: Programme?, next: Programme?) {
        let list = programmes(channelId)
        guard let index = list.firstIndex(where: { $0.stop > now }) else { return (nil, nil) }
        let first = list[index]
        if first.start <= now { return (first, index + 1 < list.count ? list[index + 1] : nil) }
        return (nil, first)
    }

    public static func + (a: Guide, b: Guide) -> Guide {
        Guide(a.byChannel.merging(b.byChannel) { one, two in Xmltv.sortedByStart(one + two) })
    }
}

/// Reads a TV guide in the XMLTV form.
public enum Xmltv {
    /// A playlist and a guide can write one channel in two forms, such as
    /// `News24.al@SD` and `News.24.al`. Both become `news24al`.
    public static func channelKey(_ id: String) -> String {
        lettersAndDigits(String(id.prefix { $0 != "@" }))
    }

    /// The key with its `@` part, such as `news24al@sd`. It keeps two feeds of one channel apart.
    public static func fullKey(_ id: String) -> String {
        guard let at = id.firstIndex(of: "@") else { return channelKey(id) }
        let feed = lettersAndDigits(String(id[id.index(after: at)...]))
        return feed.isEmpty ? channelKey(id) : channelKey(id) + "@" + feed
    }

    private static func lettersAndDigits(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars {
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .decimalNumber:
                scalars.append(scalar)
            default: break
            }
        }
        return String(scalars)
    }

    /// Reads `data`. A guide file can be very large, so this keeps only the channels
    /// in `channelIds` and only the programmes between `from` and `to`. Nil keeps all channels.
    /// XML that is not correct throws.
    public static func parse(_ data: Data, channelIds: Set<String>?, from: Int64, to: Int64) throws -> Guide {
        try parse(XMLParser(data: data), channelIds: channelIds, from: from, to: to)
    }

    /// Reads the guide in `file` one part at a time, so that the full file does not go
    /// into the memory. The rules are those of `parse(_:channelIds:from:to:)`.
    public static func parse(file: URL, channelIds: Set<String>?, from: Int64, to: Int64) throws -> Guide {
        guard let stream = InputStream(url: file) else { throw XmltvError(message: "The guide file does not open") }
        return try parse(XMLParser(stream: stream), channelIds: channelIds, from: from, to: to)
    }

    private static func parse(_ parser: XMLParser, channelIds: Set<String>?, from: Int64, to: Int64) throws -> Guide {
        let reader = Reader(wanted: channelIds.map { Set($0.map(channelKey)) }, from: from, to: to)
        parser.delegate = reader
        guard parser.parse() else {
            throw parser.parserError ?? XmltvError(message: "The guide is not correct XML")
        }
        return Guide(reader.result.mapValues(sortedByStart))
    }

    static func sortedByStart(_ list: [Programme]) -> [Programme] {
        // The index keeps two programmes with one start time in their order.
        list.enumerated().sorted { ($0.element.start, $0.offset) < ($1.element.start, $1.offset) }.map(\.element)
    }

    /// Reads a time such as `20261008120000 +0200`. With no offset, it uses UTC.
    /// A time that is not correct gives 0.
    public static func parseTime(_ value: String?) -> Int64 {
        guard let value else { return 0 }
        let units = Array(value.utf16)
        guard units.count >= 14 else { return 0 }
        var digits: [Int] = []
        for unit in units[0..<14] {
            guard unit >= 0x30, unit <= 0x39 else { return 0 }
            digits.append(Int(unit) - 0x30)
        }
        func number(_ start: Int, _ count: Int) -> Int { digits[start..<(start + count)].reduce(0) { $0 * 10 + $1 } }
        let year = number(0, 4), month = number(4, 2), hour = number(8, 2), minute = number(10, 2), second = number(12, 2)
        guard year >= 1, (1...12).contains(month), (1...31).contains(number(6, 2)),
              (0...59).contains(minute), (0...59).contains(second) else { return 0 }
        // A day after the end of the month becomes its last day, as in the smart mode of java.time.
        let day = min(number(6, 2), daysIn(month, of: year))
        var extraDays = 0
        if hour == 24 && minute == 0 && second == 0 { extraDays = 1 }
        else if hour > 23 { return 0 }

        let offsetText = String(decoding: units[14...], as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let offset = offsetSeconds(offsetText) else { return 0 }
        let days = daysFromCivil(year, month, day) + Int64(extraDays)
        let seconds = days * 86_400 + Int64(hour % 24 * 3_600 + minute * 60 + second) - Int64(offset)
        return seconds * 1_000
    }

    /// Reads an offset as `java.time.ZoneOffset.of` does. A text of five characters such as
    /// `+0200` gets a colon first. Nil when the text is not an offset.
    private static func offsetSeconds(_ text: String) -> Int? {
        if text.isEmpty || text == "Z" { return 0 }
        var chars = Array(text.utf16)
        if chars.count == 5 { chars.insert(0x3a, at: 3) }
        guard let sign = chars.first, sign == 0x2b || sign == 0x2d else { return nil }
        func two(_ i: Int) -> Int? {
            guard i + 1 < chars.count, (0x30...0x39).contains(chars[i]), (0x30...0x39).contains(chars[i + 1]) else { return nil }
            return Int(chars[i] - 0x30) * 10 + Int(chars[i + 1] - 0x30)
        }
        func colon(_ i: Int) -> Bool { chars[i] == 0x3a }
        var hours = 0, minutes = 0, seconds = 0
        switch chars.count {
        case 2:
            guard (0x30...0x39).contains(chars[1]) else { return nil }
            hours = Int(chars[1] - 0x30)
        case 3: guard let h = two(1) else { return nil }; hours = h
        case 6:
            guard let h = two(1), colon(3), let m = two(4) else { return nil }
            hours = h; minutes = m
        case 7:
            guard let h = two(1), let m = two(3), let s = two(5) else { return nil }
            hours = h; minutes = m; seconds = s
        case 9:
            guard let h = two(1), colon(3), let m = two(4), colon(6), let s = two(7) else { return nil }
            hours = h; minutes = m; seconds = s
        default: return nil
        }
        guard hours <= 18, minutes <= 59, seconds <= 59 else { return nil }
        let total = hours * 3_600 + minutes * 60 + seconds
        guard total <= 18 * 3_600 else { return nil }
        return sign == 0x2d ? -total : total
    }

    private static func daysIn(_ month: Int, of year: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// The number of days from 1970-01-01 to a date of the proleptic Gregorian calendar.
    private static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int64 {
        let y = Int64(month <= 2 ? year - 1 : year)
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = Int64((153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1)
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// Collects the programmes while the XML parser reads the file.
    private final class Reader: NSObject, XMLParserDelegate {
        let wanted: Set<String>?
        let from: Int64
        let to: Int64
        var result: [String: [Programme]] = [:]

        private var channel: String?
        private var start: Int64 = 0
        private var stop: Int64 = 0
        private var title: String?
        private var desc: String?
        // The element whose text this reads now, "title" or "desc", and the text so far.
        private var capture: String?
        private var text = ""

        init(wanted: Set<String>?, from: Int64, to: Int64) {
            self.wanted = wanted
            self.from = from
            self.to = to
        }

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            switch name {
            case "programme":
                channel = attributes["channel"]
                start = Xmltv.parseTime(attributes["start"])
                stop = Xmltv.parseTime(attributes["stop"])
                title = nil
                desc = nil
                capture = nil
            case "title" where channel != nil && title == nil && capture == nil,
                 "desc" where channel != nil && desc == nil && capture == nil:
                capture = name
                text = ""
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capture != nil { text += string }
        }

        func parser(_ parser: XMLParser, foundCDATA block: Data) {
            if capture != nil { text += String(decoding: block, as: UTF8.self) }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            if name == capture {
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if name == "title" { title = value } else { desc = value }
                capture = nil
            } else if name == "programme" {
                if let id = channel, wanted?.contains(Xmltv.channelKey(id)) ?? true, stop > from, start < to, start > 0 {
                    result[Xmltv.fullKey(id), default: []].append(
                        Programme(channelId: id, title: title ?? "", start: start, stop: stop, description: desc)
                    )
                }
                channel = nil
                capture = nil
            }
        }
    }
}

public struct XmltvError: Error, Equatable, CustomStringConvertible {
    public let message: String
    public var description: String { message }
}
