import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: Task<Void, Never>?
    private var autoShowOnNewTrack: Bool {
        get { UserDefaults.standard.bool(forKey: "humAutoShowOnNewTrack") }
        set { UserDefaults.standard.set(newValue, forKey: "humAutoShowOnNewTrack") }
    }
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

        let fontSizeLabel = NSMenuItem(title: "Text Size: \(Int(lyricsState.fontSize))pt", action: nil, keyEquivalent: "")
        fontSizeLabel.tag = 4
        menu.addItem(fontSizeLabel)

        let fontStepperItem = NSMenuItem()
        let fontStepper = NSStepper()
        fontStepper.minValue = 12
        fontStepper.maxValue = 36
        fontStepper.increment = 2
        fontStepper.doubleValue = Double(lyricsState.fontSize)
        fontStepper.target = self
        fontStepper.action = #selector(fontSizeChanged(_:))
        fontStepper.frame = CGRect(x: 8, y: 0, width: 100, height: 22)
        fontStepperItem.view = fontStepper
        menu.addItem(fontStepperItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide Lyrics",
            action: #selector(toggleLyricsVisibility),
            keyEquivalent: ""
        )
        hideItem.tag = 2
        hideItem.target = self
        menu.addItem(hideItem)

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        let autoShowItem = NSMenuItem(
            title: "Auto-show on New Track",
            action: #selector(toggleAutoShow),
            keyEquivalent: ""
        )
        autoShowItem.tag = 3
        autoShowItem.state = autoShowOnNewTrack ? .on : .off
        autoShowItem.target = self
        menu.addItem(autoShowItem)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Hum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
    }

    @objc private func fontSizeChanged(_ stepper: NSStepper) {
        let size = CGFloat(stepper.doubleValue)
        lyricsState.fontSize = size
        UserDefaults.standard.set(Double(size), forKey: "humFontSize")
        statusItem.menu?.item(withTag: 4)?.title = "Text Size: \(Int(size))pt"
    }

    @objc private func toggleLaunchAtLogin(_ item: NSMenuItem) {
        LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
        item.state = LaunchAtLoginManager.isEnabled ? .on : .off
    }

    @objc private func toggleLyricsVisibility() {
        lyricsState.isManuallyHidden = !lyricsState.isManuallyHidden
    }

    @objc private func toggleAutoShow() {
        autoShowOnNewTrack = !autoShowOnNewTrack
        statusItem.menu?.item(withTag: 3)?.state = autoShowOnNewTrack ? .on : .off
    }

    private func observe() {
        musicObserver.$currentTrack
            .removeDuplicates()
            .sink { [weak self] track in
                guard let self else { return }
                self.fetchTask?.cancel()
                self.fetchTask = Task { @MainActor in await self.handleTrackChange(track) }
            }
            .store(in: &cancellables)

        let hasContentPublisher = lyricsState.$lines
            .combineLatest(lyricsState.$noLyricsFound)
            .map { lines, noLyrics in !lines.isEmpty || noLyrics }

        Publishers.CombineLatest3(musicObserver.$isPlaying, hasContentPublisher, lyricsState.$isManuallyHidden)
            .sink { [weak self] isPlaying, hasContent, isHidden in
                guard let self else { return }
                if isPlaying && hasContent && !isHidden {
                    self.windowManager.show()
                } else {
                    self.windowManager.hide()
                }
            }
            .store(in: &cancellables)

        lyricsState.$isManuallyHidden
            .sink { [weak self] isHidden in
                self?.statusItem.menu?.item(withTag: 2)?.title = isHidden ? "Show Lyrics" : "Hide Lyrics"
            }
            .store(in: &cancellables)

        lyricsState.$isMinimized
            .sink { [weak self] isMinimized in
                guard let self else { return }
                self.windowManager.setMinimized(isMinimized)
            }
            .store(in: &cancellables)
    }

    private func handleTrackChange(_ track: Track?) async {
        guard let track else {
            lyricsState.lines = []
            lyricsState.noLyricsFound = false
            return
        }
        lyricsState.lines = []
        lyricsState.noLyricsFound = false
        if autoShowOnNewTrack {
            lyricsState.isManuallyHidden = false
        }
        let lines = await lyricsEngine.fetch(for: track)
        guard !Task.isCancelled else { return }
        lyricsState.lines = lines
        lyricsState.noLyricsFound = lines.isEmpty
    }
}
