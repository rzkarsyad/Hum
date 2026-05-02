import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private let musicObserver: MusicObserver
    private let lyricsEngine: LyricsEngine
    private let lyricsState: LyricsState
    private let windowManager: WindowManager

    init(
        musicObserver: MusicObserver,
        lyricsEngine: LyricsEngine,
        lyricsState: LyricsState,
        windowManager: WindowManager
    ) {
        self.musicObserver = musicObserver
        self.lyricsEngine = lyricsEngine
        self.lyricsState = lyricsState
        self.windowManager = windowManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Hum")
        buildMenu()
        observe()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let offsetLabel = NSMenuItem(title: "Sync Offset: +0.0s", action: nil, keyEquivalent: "")
        offsetLabel.tag = 1
        menu.addItem(offsetLabel)

        let stepperItem = NSMenuItem()
        let stepper = NSStepper()
        stepper.minValue = -5
        stepper.maxValue = 5
        stepper.increment = 0.5
        stepper.doubleValue = 0
        stepper.target = self
        stepper.action = #selector(offsetChanged(_:))
        stepper.frame = CGRect(x: 8, y: 0, width: 100, height: 22)
        stepperItem.view = stepper
        menu.addItem(stepperItem)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Hum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
    }

    @objc private func offsetChanged(_ stepper: NSStepper) {
        lyricsState.syncOffset = stepper.doubleValue
        let val = stepper.doubleValue
        let sign = val >= 0 ? "+" : ""
        statusItem.menu?.item(withTag: 1)?.title = "Sync Offset: \(sign)\(val)s"
    }

    private func observe() {
        musicObserver.$currentTrack
            .removeDuplicates()
            .sink { [weak self] track in
                guard let self else { return }
                Task { @MainActor in await self.handleTrackChange(track) }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(musicObserver.$isPlaying, lyricsState.$lines)
            .sink { [weak self] isPlaying, lines in
                guard let self else { return }
                if isPlaying && !lines.isEmpty {
                    self.windowManager.show()
                } else {
                    self.windowManager.hide()
                }
            }
            .store(in: &cancellables)
    }

    private func handleTrackChange(_ track: Track?) async {
        guard let track else { lyricsState.lines = []; return }
        lyricsState.lines = await lyricsEngine.fetch(for: track)
    }
}
