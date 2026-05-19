import AppKit
import SwiftUI

final class WindowManager: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private var savedHeight: CGFloat = 276

    init(lyricsState: LyricsState, musicObserver: MusicObserver) {
        panel = FloatingPanel()
        super.init()
        panel.delegate = self
        let rootView = HumWindowView(lyricsState: lyricsState, musicObserver: musicObserver)
        panel.contentView = NSHostingView(rootView: rootView)
        restoreOrSetDefaultPosition()
    }

    func show() {
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
    }

    func setMinimized(_ minimized: Bool) {
        let headerHeight: CGFloat = 52
        if minimized {
            // Save current height before collapsing (only if not already minimized)
            if panel.frame.height > headerHeight + 20 {
                savedHeight = panel.frame.height
            }
            let newFrame = CGRect(
                x: panel.frame.minX,
                y: panel.frame.maxY - headerHeight,
                width: panel.frame.width,
                height: headerHeight
            )
            panel.setFrame(newFrame, display: true, animate: true)
        } else {
            let newFrame = CGRect(
                x: panel.frame.minX,
                y: panel.frame.maxY - savedHeight,
                width: panel.frame.width,
                height: savedHeight
            )
            panel.setFrame(newFrame, display: true, animate: true)
        }
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        // Don't save when window is in minimized state (header only)
        guard panel.frame.height > 80 else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame")
    }

    private func restoreOrSetDefaultPosition() {
        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            let savedFrame = NSRectFromString(saved)
            if savedFrame != .zero {
                panel.setFrame(savedFrame, display: false)
                savedHeight = savedFrame.height
                return
            }
        }
        let size = CGSize(width: 320, height: 276)
        savedHeight = size.height
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
        minSize = CGSize(width: 200, height: 52)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let cv = contentView else { return }
        let b = cv.bounds
        let e: CGFloat = 8
        cv.addCursorRect(CGRect(x: 0,           y: e,           width: e, height: b.height - 2*e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: e,           width: e, height: b.height - 2*e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: e,           y: 0,           width: b.width - 2*e, height: e),  cursor: .resizeUpDown)
        cv.addCursorRect(CGRect(x: e,           y: b.height - e, width: b.width - 2*e, height: e), cursor: .resizeUpDown)
        cv.addCursorRect(CGRect(x: 0,           y: 0,           width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: 0,           width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: 0,           y: b.height - e, width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: b.height - e, width: e, height: e), cursor: .resizeLeftRight)
    }
}
