import SwiftUI
import UniformTypeIdentifiers

// MARK: - Asosiy ekran

@MainActor
struct ContentView: View {
    @EnvironmentObject var store: PlaylistStore
    @EnvironmentObject var pm: PlayerManager
    @State private var showAdd = false
    @State private var showPlayer = false
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.playlists.isEmpty {
                    EmptyStateView { showAdd = true }
                } else {
                    channelList
                }
            }
            .navigationTitle("BepulTV")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .searchable(text: $search, prompt: "Kanal qidirish")
        }
        .safeAreaInset(edge: .bottom) {
            MiniPlayer { showPlayer = true }
        }
        .sheet(isPresented: $showAdd) { AddPlaylistView() }
        .fullScreenCover(isPresented: $showPlayer) { PlayerScreen() }
        .alert("Xato", isPresented: errorShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pm.errorMessage ?? "")
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { pm.errorMessage != nil },
                set: { if !$0 { pm.errorMessage = nil } })
    }

    private var channelList: some View {
        List {
            let favs = filter(store.favoriteChannels)
            if !favs.isEmpty {
                Section("Sevimlilar") {
                    ForEach(favs) { row($0, in: store.favoriteChannels) }
                }
            }
            ForEach(store.playlists) { pl in
                Section {
                    ForEach(filter(pl.channels)) { row($0, in: pl.channels) }
                } header: {
                    HStack {
                        Text("\(pl.name) · \(pl.channels.count)")
                        Spacer()
                        Menu {
                            if pl.sourceURL != nil {
                                Button {
                                    Task {
                                        do { try await store.refresh(pl) }
                                        catch { pm.errorMessage = error.localizedDescription }
                                    }
                                } label: { Label("Yangilash", systemImage: "arrow.clockwise") }
                            }
                            Button(role: .destructive) { store.delete(pl) } label: {
                                Label("O'chirish", systemImage: "trash")
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                    .textCase(nil)
                }
            }
        }
    }

    private func filter(_ channels: [Channel]) -> [Channel] {
        guard let q = search.nonEmpty else { return channels }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func row(_ ch: Channel, in list: [Channel]) -> some View {
        let fav = store.isFavorite(ch)
        return Button {
            pm.play(ch, in: list)
            showPlayer = true
        } label: {
            HStack(spacing: 12) {
                ChannelLogo(url: ch.logo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ch.name).foregroundStyle(.primary).lineLimit(1)
                    if let g = ch.group {
                        Text(g).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if fav { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                if pm.current?.url == ch.url {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
                }
            }
        }
        .swipeActions {
            Button { store.toggleFavorite(ch) } label: {
                Label(fav ? "Olib tashlash" : "Sevimli", systemImage: fav ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
    }
}

// MARK: - Bo'sh holat

struct EmptyStateView: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.tv").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("Hali pleylist yo'q").font(.title3.bold())
            Text("M3U pleylist havolasini, faylini yoki bitta kanal havolasini qo'shing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Pleylist qo'shish", action: onAdd)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Qo'shish oynasi

@MainActor
struct AddPlaylistView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case link = "Havola", file = "Fayl", single = "Bitta kanal"
        var id: Self { self }
    }

    @EnvironmentObject var store: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .link
    @State private var name = ""
    @State private var urlText = ""
    @State private var showImporter = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Turi", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Section {
                    TextField(mode == .single ? "Kanal nomi" : "Nomi (ixtiyoriy)", text: $name)
                    if mode != .file {
                        TextField(mode == .single ? "Oqim havolasi (.m3u8)" : "M3U pleylist havolasi",
                                  text: $urlText)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    Text(footer)
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if busy { ProgressView() }
                            else { Text(mode == .file ? "Faylni tanlash" : "Qo'shish").bold() }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Qo'shish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Bekor") { dismiss() } }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: importTypes) { result in
                switch result {
                case .success(let url): run { try await store.addPlaylist(from: url, name: name) }
                case .failure(let e): error = e.localizedDescription
                }
            }
        }
    }

    private var footer: String {
        switch mode {
        case .link: return "Masalan: https://…/playlist.m3u — faqat o'zingiz foydalanish huquqiga ega bo'lgan manbalarni qo'shing."
        case .file: return "Telefoningizdagi .m3u yoki .m3u8 faylni tanlang (Fayllar ilovasidan)."
        case .single: return "Bitta jonli efir yoki video havolasi (HLS .m3u8, .mp4, .mp3)."
        }
    }

    private var canSubmit: Bool {
        if busy { return false }
        switch mode {
        case .file: return true
        case .link: return urlText.nonEmpty != nil
        case .single: return urlText.nonEmpty != nil && name.nonEmpty != nil
        }
    }

    private var importTypes: [UTType] {
        [UTType(filenameExtension: "m3u"), UTType(filenameExtension: "m3u8"), .plainText, .data]
            .compactMap { $0 }
    }

    private func parsedURL() -> URL? {
        guard let text = urlText.nonEmpty, let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    private func submit() {
        error = nil
        switch mode {
        case .file:
            showImporter = true
        case .link:
            guard let url = parsedURL() else { error = "Havola noto'g'ri. http:// yoki https:// bilan boshlanishi kerak."; return }
            run { try await store.addPlaylist(from: url, name: name) }
        case .single:
            guard let url = parsedURL() else { error = "Havola noto'g'ri. http:// yoki https:// bilan boshlanishi kerak."; return }
            store.addSingle(name: name.nonEmpty ?? url.lastPathComponent, url: url)
            dismiss()
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        busy = true
        Task {
            do {
                try await operation()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

// MARK: - Pleyer ekrani

@MainActor
struct PlayerScreen: View {
    @EnvironmentObject var pm: PlayerManager
    @EnvironmentObject var store: PlaylistStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").font(.title2.bold())
                }
                Spacer()
            }
            .padding(.horizontal)

            PlayerView(player: pm.player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)

            if let ch = pm.current {
                VStack(spacing: 4) {
                    Text(ch.name).font(.title3.bold()).multilineTextAlignment(.center)
                    if let g = ch.group { Text(g).foregroundStyle(.secondary) }
                }
                .padding(.horizontal)

                HStack(spacing: 44) {
                    Button { pm.previous() } label: { Image(systemName: "backward.fill") }
                    Button { pm.togglePlayPause() } label: {
                        Image(systemName: pm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    Button { pm.next() } label: { Image(systemName: "forward.fill") }
                }
                .font(.title)

                Button { store.toggleFavorite(ch) } label: {
                    Label(store.isFavorite(ch) ? "Sevimlilarda" : "Sevimlilarga qo'shish",
                          systemImage: store.isFavorite(ch) ? "star.fill" : "star")
                }
            }

            Text("Ekranni bloklasangiz ham ovoz davom etadi. Qulf ekranidan yoki Boshqaruv markazidan boshqarasiz.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }
}

// MARK: - Pastki mini pleyer

@MainActor
struct MiniPlayer: View {
    @EnvironmentObject var pm: PlayerManager
    var onOpen: () -> Void

    var body: some View {
        if let ch = pm.current {
            HStack(spacing: 12) {
                ChannelLogo(url: ch.logo, size: 40)
                Text(ch.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Button { pm.togglePlayPause() } label: {
                    Image(systemName: pm.isPlaying ? "pause.fill" : "play.fill").font(.title2)
                }
                Button { pm.stop() } label: {
                    Image(systemName: "xmark").font(.title3)
                }
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
        }
    }
}

// MARK: - Kanal logotipi

struct ChannelLogo: View {
    let url: URL?
    var size: CGFloat = 44

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
