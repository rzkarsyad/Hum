import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private let musicObserver = MusicObserver()
    private let lyricsEngine = LyricsEngine()
    private let lyricsState = LyricsState()
    private var windowManager: WindowManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = WindowManager(lyricsState: lyricsState, musicObserver: musicObserver)
        statusBarController = StatusBarController(
            musicObserver: musicObserver,
            lyricsEngine: lyricsEngine,
            lyricsState: lyricsState,
            windowManager: windowManager
        )
        musicObserver.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        musicObserver.stop()
    }
}
