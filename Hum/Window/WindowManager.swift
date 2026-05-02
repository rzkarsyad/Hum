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
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame")
    }

    private func restoreOrSetDefaultPosition() {
        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            let frame = NSRectFromString(saved)
            if frame != .zero { panel.setFrame(frame, display: false); return }
        }
        guard let screen = NSScreen.main else { return }
        let size = CGSize(width: 320, height: 220)
        let origin = CGPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 60
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }
}

private final class FloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
