import AppKit
import SwiftUI

final class WindowManager: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel

    init(lyricsState: LyricsState, musicObserver: MusicObserver) {
        panel = FloatingPanel()
        super.init()
        panel.delegate = self
        let rootView = HumWindowView(lyricsState: lyricsState, musicObserver: musicObserver)
        panel.contentView = NSHostingView(rootView: rootView)
        restoreOrSetDefaultPosition()
    }

    func show() { panel.orderFront(nil) }
    func hide() { panel.orderOut(nil) }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame")
    }

    private func restoreOrSetDefaultPosition() {
        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            let savedFrame = NSRectFromString(saved)
            if savedFrame != .zero {
                panel.setFrame(savedFrame, display: false)
                return
            }
        }
        let size = CGSize(width: 320, height: 276)
        guard let screen = NSScreen.main else { return }
        let origin = CGPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 60
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }
}

private final class FloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = CGSize(width: 200, height: 150)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let cv = contentView else { return }
        let b = cv.bounds
        let e: CGFloat = 8

        // Left and right edges → horizontal resize cursor
        cv.addCursorRect(CGRect(x: 0,            y: e,            width: e, height: b.height - 2 * e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e,  y: e,            width: e, height: b.height - 2 * e), cursor: .resizeLeftRight)

        // Top and bottom edges → vertical resize cursor
        cv.addCursorRect(CGRect(x: e,            y: 0,            width: b.width - 2 * e, height: e), cursor: .resizeUpDown)
        cv.addCursorRect(CGRect(x: e,            y: b.height - e, width: b.width - 2 * e, height: e), cursor: .resizeUpDown)

        // Corners → horizontal resize cursor (no diagonal cursor in NSCursor)
        cv.addCursorRect(CGRect(x: 0,           y: 0,            width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: 0,            width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: 0,           y: b.height - e, width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: b.height - e, width: e, height: e), cursor: .resizeLeftRight)
    }
}
