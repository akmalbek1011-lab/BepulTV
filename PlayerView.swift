import SwiftUI
import AVKit

/// Video oynasi. Ekran bloklanganda videoni pleyerdan uzib qo'yadi,
/// shunda iOS ovozni to'xtatmaydi (Apple tavsiya qilgan usul).
struct PlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeCoordinator() -> Coordinator { Coordinator(player: player) }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.allowsPictureInPicturePlayback = true
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        vc.updatesNowPlayingInfoCenter = false
        vc.delegate = context.coordinator
        context.coordinator.controller = vc
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let player: AVPlayer
        weak var controller: AVPlayerViewController?
        private var pictureInPictureActive = false

        init(player: AVPlayer) {
            self.player = player
            super.init()
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(didEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
            nc.addObserver(self, selector: #selector(willEnterForeground),
                           name: UIApplication.willEnterForegroundNotification, object: nil)
        }

        @objc private func didEnterBackground() {
            if !pictureInPictureActive { controller?.player = nil }
        }

        @objc private func willEnterForeground() {
            controller?.player = player
        }

        func playerViewControllerWillStartPictureInPicture(_ c: AVPlayerViewController) {
            pictureInPictureActive = true
        }

        func playerViewControllerDidStopPictureInPicture(_ c: AVPlayerViewController) {
            pictureInPictureActive = false
        }
    }
}
