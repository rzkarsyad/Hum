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
        let hostingView = NSHostingView(rootView: rootView)

        // The transparent CursorOverlayView sits above the SwiftUI content so it wins
        // hit-testing at the window edges and owns the resize-cursor tracking area.
        let container = WindowContainerView()
        container.addSubview(hostingView)
        container.addSubview(CursorOverlayView())
        panel.contentView = container

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
}

// Always fills its subviews to its own bounds so the hosting view and cursor overlay
// stay in sync with the window's content area through every resize.
private final class WindowContainerView: NSView {
    override func layout() {
        super.layout()
        subviews.forEach { $0.frame = bounds }
    }
}

// Transparent overlay placed above the SwiftUI content. A tracking area with
// `.activeAlways` drives the cursor regardless of key-window status — FloatingPanel is a
// non-activating NSPanel that can never become key, so AppKit's cursor-rectangle
// mechanism (addCursorRect/resetCursorRects) is never evaluated for it and resize cursors
// would never show. hitTest still returns self only on the 8-pt resize border so edge
// drags resize the window while interior events fall through to SwiftUI as normal.
private final class CursorOverlayView: NSView {
    private let e: CGFloat = 8
    private var active: NSCursor = .arrow

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        set(cursor(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        set(.arrow)
    }

    // Set only on change so we don't stomp cursors SwiftUI manages in the interior.
    private func set(_ cursor: NSCursor) {
        guard cursor !== active else { return }
        active = cursor
        cursor.set()
    }

    private func cursor(at p: NSPoint) -> NSCursor {
        let b = bounds
        let nearX = p.x < e || p.x > b.width - e
        let nearY = p.y < e || p.y > b.height - e
        switch (nearX, nearY) {
        case (true, false): return .resizeLeftRight
        case (false, true): return .resizeUpDown
        case (true, true):  return .resizeLeftRight   // corners — match prior behavior
        default:            return .arrow
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = convert(point, from: superview)
        let b = bounds
        let inEdge = local.x < e || local.x > b.width - e || local.y < e || local.y > b.height - e
        return inEdge ? self : nil
    }
}
