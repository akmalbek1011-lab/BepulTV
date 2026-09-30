import Foundation

struct Channel: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var url: URL
    var logo: URL?
    var group: String?
}

struct Playlist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sourceURL: URL?
    var channels: [Channel]
}

/// M3U / M3U8 pleylistlarni o'qiydi (#EXTINF, tvg-logo, group-title).
enum M3UParser {
    static func parse(_ text: String) -> [Channel] {
        var result: [Channel] = []
        var name: String?
        var logo: URL?
        var group: String?

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
            if line.isEmpty { continue }

            if line.hasPrefix("#EXTINF") {
                name = title(from: line)
                logo = attribute("tvg-logo", in: line).flatMap { URL(string: $0) }
                group = attribute("group-title", in: line)
            } else if line.hasPrefix("#") {
                continue
            } else if let url = URL(string: line), url.scheme != nil {
                let finalName = (name?.isEmpty == false) ? name! : url.lastPathComponent
                result.append(Channel(name: finalName, url: url, logo: logo, group: group))
                name = nil; logo = nil; group = nil
            }
        }
        return result
    }

    /// `key="qiymat"` ko'rinishidagi atributni oladi.
    static func attribute(_ key: String, in line: String) -> String? {
        guard let start = line.range(of: key + "=\"") else { return nil }
        let rest = line[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let value = String(rest[..<end])
        return value.isEmpty ? nil : value
    }

    /// Qo'shtirnoq ichida bo'lmagan birinchi verguldan keyingi matn — kanal nomi.
    static func title(from line: String) -> String {
        var inQuotes = false
        for idx in line.indices {
            let c = line[idx]
            if c == "\"" {
                inQuotes.toggle()
            } else if c == ",", !inQuotes {
                return String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }
}

extension String {
    var nonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
