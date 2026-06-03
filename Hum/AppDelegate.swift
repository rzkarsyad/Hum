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
        // Skip UI/observer setup when hosted by the XCTest runner: launching the
        // status bar, music polling, and onboarding window during tests crashes
        // the test host (constraint loop in the onboarding window).
        if NSClassFromString("XCTestCase") != nil { return }

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

        // Size the window to the view's natural height (its width is locked to 380 inside
        // the view). NSHostingView's default sizingOptions push the content's size onto the
        // window as constraints; against a hardcoded height that doesn't match the content,
        // the window's Update Constraints pass never settles and AppKit aborts the app. So:
        // measure the content first, then disable those sizing constraints before showing.
        let hosting = NSHostingView(rootView: view)
        let contentHeight = hosting.fittingSize.height
        hosting.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: contentHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.title = "Welcome to Hum"
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
