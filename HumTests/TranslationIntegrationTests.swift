import XCTest
import SwiftUI
import Combine
import Translation
@testable import Hum

/// On-device verification of the lyric-translation feature.
///
/// Unlike the rest of the suite this mounts the *real* `HumWindowView` in a
/// window and lets the *real* Translation framework run, so it exercises the
/// whole path: the `.translationTask` wiring, the configuration built on
/// `lines.count` change, `invalidate()` re-running the batch for a new track,
/// and the `usefulTranslations` filter.
///
/// Skipped when this machine has no model for the language pair, so the suite
/// stays green on a device that has never downloaded one.
@MainActor
final class TranslationIntegrationTests: XCTestCase {

    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() async throws {
        window?.close()
        window = nil
        cancellables.removeAll()
    }

    private func mount(_ lyricsState: LyricsState, _ observer: MusicObserver) {
        // Must be a real, on-screen window: SwiftUI does not run the update
        // cycle (and therefore never fires onChange / translationTask) for a
        // hosting view in an off-screen window.
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 420, height: 260),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(
            rootView: HumWindowView(lyricsState: lyricsState, musicObserver: observer)
        )
        // NSWindow releases itself on close by default; with ARC also holding it
        // that over-releases and crashes the test host during tearDown.
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        self.window = window
    }

    /// Fulfils once `translations` is non-empty (the view clears it to `[:]`
    /// whenever it rebuilds the configuration, so empty values are ignored).
    private func expectTranslations(_ lyricsState: LyricsState,
                                    _ description: String) -> XCTestExpectation {
        let exp = expectation(description: description)
        exp.assertForOverFulfill = false
        lyricsState.$translations
            // @Published replays its current value on subscription; that stale
            // value would fulfil the expectation before the new batch ran.
            .dropFirst()
            .filter { !$0.isEmpty }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        return exp
    }

    func test_translatesLyricsAndReRunsOnTrackChange() async throws {
        let target = Locale.current.language
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: "id"), to: target
        )
        try XCTSkipIf(
            status == .unsupported,
            "No Indonesian → \(target.languageCode?.identifier ?? "?") model path on this device"
        )

        let lyricsState = LyricsState()
        lyricsState.showTranslation = true
        let observer = MusicObserver()

        // Lyrics already loaded before the window is built — the common case,
        // since the panel is created on demand once playback starts.
        lyricsState.lines = [
            LyricLine(timestamp: 0, text: "Aku mencintaimu selamanya"),
            LyricLine(timestamp: 2, text: "Langit malam begitu indah"),
            LyricLine(timestamp: 4, text: "Jangan pergi dari sisiku")
        ]
        let first = expectTranslations(lyricsState, "first track translated")
        mount(lyricsState, observer)
        await fulfillment(of: [first], timeout: 120)

        let firstRun = lyricsState.translations
        XCTAssertEqual(firstRun.count, 3, "every lyric line should get a translation")
        for (index, line) in lyricsState.lines.enumerated() {
            let translated = try XCTUnwrap(firstRun[index], "line \(index) missing a translation")
            XCTAssertNotEqual(translated, line.text, "line \(index) came back untranslated")
            XCTAssertFalse(translated.isEmpty)
        }

        // A new track: different line count invalidates the configuration and
        // must re-run the batch rather than leaving the old track's text.
        cancellables.removeAll()
        let second = expectTranslations(lyricsState, "second track translated")
        lyricsState.lines = [
            LyricLine(timestamp: 0, text: "Hujan turun di kota ini"),
            LyricLine(timestamp: 3, text: "Aku menunggumu pulang")
        ]
        await fulfillment(of: [second], timeout: 120)

        let secondRun = lyricsState.translations
        XCTAssertEqual(secondRun.count, 2, "translations should match the new track, not the old one")
        XCTAssertNotEqual(secondRun[0], firstRun[0], "stale translation left over from the previous track")
    }
}
