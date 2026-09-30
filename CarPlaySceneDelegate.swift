import CarPlay

/// CarPlay qismi: audio ilova sifatida kanallar ro'yxati va "Hozir ijroda" ekrani.
/// DIQQAT: Apple `com.apple.developer.carplay-audio` ruxsatini bermaguncha
/// iOS bu ilovani mashina ekranida ko'rsatmaydi. Kod tayyor turadi.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var tabBar: CPTabBarTemplate?
    private let store = PlaylistStore.shared
    private let pm = PlayerManager.shared

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let tabBar = CPTabBarTemplate(templates: makeTabs())
        self.tabBar = tabBar
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        store.onChange = { [weak self] in self?.reload() }
        pm.onStateChange = { [weak self] in self?.reload() }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        self.tabBar = nil
        store.onChange = nil
        pm.onStateChange = nil
    }

    private func reload() {
        tabBar?.updateTemplates(makeTabs())
    }

    private func makeTabs() -> [CPTemplate] {
        var tabs: [CPTemplate] = [
            listTemplate(title: "Sevimlilar", channels: store.favoriteChannels, icon: "star.fill")
        ]
        let room = max(0, CPTabBarTemplate.maximumTabCount - 1)
        for pl in store.playlists.prefix(room) {
            tabs.append(listTemplate(title: pl.name, channels: pl.channels, icon: "list.bullet"))
        }
        return tabs
    }

    private func listTemplate(title: String, channels: [Channel], icon: String) -> CPListTemplate {
        let items: [CPListItem] = channels.prefix(CPListTemplate.maximumItemCount).map { ch in
            let item = CPListItem(text: ch.name, detailText: ch.group)
            item.isPlaying = pm.current?.url == ch.url
            item.handler = { [weak self] _, completion in
                self?.pm.play(ch, in: channels)
                self?.showNowPlaying()
                completion()
            }
            return item
        }
        let template = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        template.tabTitle = title
        template.tabImage = UIImage(systemName: icon)
        template.emptyViewTitleVariants = ["Kanallar yo'q"]
        template.emptyViewSubtitleVariants = ["Telefondagi ilovada pleylist qo'shing"]
        return template
    }

    private func showNowPlaying() {
        guard let ic = interfaceController, ic.topTemplate !== CPNowPlayingTemplate.shared else { return }
        ic.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }
}
