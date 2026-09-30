import AVFoundation
import MediaPlayer
import UIKit

/// Yagona pleyer: telefon ekrani, qulf ekrani va CarPlay bir xil pleyerni boshqaradi.
@MainActor
final class PlayerManager: ObservableObject {
    static let shared = PlayerManager()

    let player = AVPlayer()
    @Published private(set) var current: Channel?
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    /// CarPlay ro'yxatidagi "ijro etilmoqda" belgisini yangilash uchun.
    var onStateChange: (() -> Void)?

    private var queue: [Channel] = []
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var interruptionObserver: NSObjectProtocol?
    private var artwork: MPMediaItemArtwork?
    private var artworkURL: URL?

    private init() {
        configureAudioSession()
        configureRemoteCommands()

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            let playing = p.timeControlStatus != .paused
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = playing
                self.updateNowPlaying()
                self.onStateChange?()
            }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            let optRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume) {
                Task { @MainActor in self?.resume() }
            }
        }
    }

    // MARK: - Boshqaruv

    func play(_ channel: Channel, in list: [Channel]? = nil) {
        if let list { queue = list }
        current = channel
        errorMessage = nil

        let item = AVPlayerItem(url: channel.url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let text = item.error?.localizedDescription ?? ""
            Task { @MainActor in self?.errorMessage = "Kanal ochilmadi. \(text)" }
        }

        try? AVAudioSession.sharedInstance().setActive(true)
        player.replaceCurrentItem(with: item)
        player.play()
        loadArtwork(for: channel)
        updateNowPlaying()
        onStateChange?()
    }

    func resume() {
        guard let ch = current else { return }
        // Jonli efir uzoq to'xtab qolsa yoki xato bo'lsa, oqimni qaytadan ochamiz.
        if player.currentItem == nil || player.currentItem?.status == .failed {
            play(ch)
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
        }
    }

    func pause() { player.pause() }

    func togglePlayPause() { isPlaying ? pause() : resume() }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation = nil
        current = nil
        updateNowPlaying()
        onStateChange?()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func next() { step(by: 1) }
    func previous() { step(by: -1) }

    private func step(by offset: Int) {
        guard let ch = current, !queue.isEmpty,
              let i = queue.firstIndex(where: { $0.id == ch.id }) else { return }
        let n = queue.count
        play(queue[((i + offset) % n + n) % n])
    }

    // MARK: - Tizim bilan bog'lanish

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
    }

    private func configureRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        c.changePlaybackPositionCommand.isEnabled = false
        c.skipForwardCommand.isEnabled = false
        c.skipBackwardCommand.isEnabled = false
    }

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let ch = current else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: ch.name,
            MPMediaItemPropertyArtist: ch.group ?? "BepulTV",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let artwork, artworkURL == ch.logo {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
    }

    private func loadArtwork(for channel: Channel) {
        artwork = nil
        artworkURL = nil
        guard let url = channel.logo else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  self.current?.logo == url else { return }
            self.artworkURL = url
            self.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self.updateNowPlaying()
        }
    }
}
