import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private let musicObserver = MusicObserver()
    private let lyricsEngine = LyricsEngine()
    private let lyricsState = LyricsState()
    private var windowManager: WindowManager!
    private var onboardingWindow: NSWindow?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = WindowManager(lyricsState: lyricsState, musicObserver: musicObserver)
        statusBarController = StatusBarController(
            musicObserver: musicObserver,
            lyricsEngine: lyricsEngine,
            lyricsState: lyricsState,
            windowManager: windowManager,
            updater: updaterController.updater
        )
        musicObserver.start()

        if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        musicObserver.stop()
    }

    private func showOnboarding() {
        let view = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view)
        window.title = "Welcome to Hum"
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
