import Foundation

enum StoreError: LocalizedError {
    case http(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Server xato qaytardi (kod \(code))."
        case .empty: return "Pleylistda birorta ham kanal topilmadi."
        }
    }
}

/// Pleylistlar va sevimlilarni saqlaydi. Ma'lumot faqat telefonning o'zida turadi.
@MainActor
final class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()
    static let myChannelsName = "Mening kanallarim"

    @Published private(set) var playlists: [Playlist] = [] {
        didSet { save(); onChange?() }
    }
    @Published private(set) var favorites: Set<URL> = [] {
        didSet { save(); onChange?() }
    }

    /// CarPlay ro'yxatini yangilash uchun.
    var onChange: (() -> Void)?

    private struct Saved: Codable {
        var playlists: [Playlist]
        var favorites: [URL]
    }

    private let fileURL: URL = {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("bepultv.json")
    }()

    private var isLoading = false

    init() { load() }

    var allChannels: [Channel] { playlists.flatMap(\.channels) }

    var favoriteChannels: [Channel] {
        var seen = Set<URL>()
        return allChannels.filter { favorites.contains($0.url) && seen.insert($0.url).inserted }
    }

    func isFavorite(_ ch: Channel) -> Bool { favorites.contains(ch.url) }

    func toggleFavorite(_ ch: Channel) {
        if favorites.contains(ch.url) { favorites.remove(ch.url) } else { favorites.insert(ch.url) }
    }

    func addPlaylist(from url: URL, name: String) async throws {
        let channels = try await Self.fetchChannels(from: url)
        let title = name.nonEmpty ?? url.deletingPathExtension().lastPathComponent
        playlists.append(Playlist(name: title, sourceURL: url.isFileURL ? nil : url, channels: channels))
    }

    func addSingle(name: String, url: URL) {
        let ch = Channel(name: name, url: url)
        if let i = playlists.firstIndex(where: { $0.name == Self.myChannelsName && $0.sourceURL == nil }) {
            playlists[i].channels.append(ch)
        } else {
            playlists.insert(Playlist(name: Self.myChannelsName, sourceURL: nil, channels: [ch]), at: 0)
        }
    }

    func refresh(_ playlist: Playlist) async throws {
        guard let src = playlist.sourceURL else { return }
        let channels = try await Self.fetchChannels(from: src)
        if let i = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[i].channels = channels
        }
    }

    func delete(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
    }

    // MARK: - Yuklash

    private static func fetchChannels(from url: URL) async throws -> [Channel] {
        let text: String
        if url.isFileURL {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            text = String(decoding: data, as: UTF8.self)
        } else {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw StoreError.http(http.statusCode)
            }
            text = String(decoding: data, as: UTF8.self)
        }
        let channels = M3UParser.parse(text)
        guard !channels.isEmpty else { throw StoreError.empty }
        return channels
    }

    // MARK: - Saqlash

    private func save() {
        guard !isLoading else { return }
        let saved = Saved(playlists: playlists, favorites: Array(favorites))
        if let data = try? JSONEncoder().encode(saved) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        playlists = saved.playlists
        favorites = Set(saved.favorites)
    }
}
