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

        // Give the container a real frame BEFORE adding subviews so their initial
        // updateTrackingAreas runs against valid bounds (not .zero).
        let initialFrame = NSRect(x: 0, y: 0, width: 320, height: 276)
        let container = WindowContainerView(frame: initialFrame)
        container.autoresizingMask = [.width, .height] as NSView.AutoresizingMask

        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height] as NSView.AutoresizingMask
        container.addSubview(hostingView)

        // Overlay added LAST so it wins hitTest at the edges.
        let overlay = CursorOverlayView(frame: container.bounds)
        container.addSubview(overlay)
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
        acceptsMouseMovedEvents = true
    }

    // Must allow key, otherwise AppKit will not dispatch cursorUpdate: to our
    // overlay's tracking areas and NSCursor.set() calls from this process are
    // silently dropped (documented: NSCursor.set is a no-op when the calling app
    // is inactive). `.nonactivatingPanel` still keeps the *app* in the
    // background — the user's foreground app remains frontmost in the menu bar.
    // The overlay makes this panel key only while the cursor is inside it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// Always fills its subviews to its own bounds so the hosting view and cursor overlay
// stay in sync with the window's content area through every resize.
private final class WindowContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizesSubviews = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        subviews.forEach { $0.frame = bounds }
    }
}

// Transparent overlay that owns the 8-pt resize border on the floating panel.
//
// Drives resize cursors via `cursorUpdate:` from a `.activeAlways + .inVisibleRect +
// .cursorUpdate` tracking area. The mechanism only works when the panel is key, so the
// overlay calls `makeKey()` on mouseEntered and `resignKey()` on mouseExited. Because the
// panel is `.nonactivatingPanel`, becoming key does NOT activate the app — the user's
// foreground app stays frontmost — but it does make our process the cursor authority so
// `cursorUpdate:` fires and `NSCursor.set()` is honored. hitTest still returns self only
// on the edge band so edge drags resize via `.resizable` while interior events fall
// through to SwiftUI.
private final class CursorOverlayView: NSView {
    private let edge: CGFloat = 8
    private var didMakeKey = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height] as NSView.AutoresizingMask
        postsFrameChangedNotifications = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Container.layout() writes our frame directly, bypassing the autoresizing
        // notification path; re-register tracking areas immediately so they don't go stale.
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // .inVisibleRect makes AppKit recompute the rect on every pass — defends
        // against a tracking area accidentally registered at .zero before layout.
        // .mouseMoved is needed alongside .cursorUpdate because cursorUpdate fires
        // only on tracking-area entry, not on intra-area position changes. We need
        // continuous resampling to switch between resizeLeftRight at the edge and
        // default in the interior of the same overlay.
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        ))
    }

    private func edgeCursor(at p: NSPoint) -> NSCursor? {
        let b = bounds
        let nearX = p.x < edge || p.x > b.width - edge
        let nearY = p.y < edge || p.y > b.height - edge
        // frameResize is the macOS 15+ window-frame resize cursor — the plain ↔ / ↕
        // arrows that AppKit itself uses for native window edges, with no split-bar.
        // columnResize / rowResize keep the bar (intended for column/row dividers).
        if nearX { return NSCursor.frameResize(position: .right, directions: .all) }   // corners follow prior behavior
        if nearY { return NSCursor.frameResize(position: .bottom, directions: .all) }
        return nil
    }

    override func mouseEntered(with event: NSEvent) {
        guard let w = window, !w.isKeyWindow else { return }
        w.makeKey()
        didMakeKey = true
    }

    override func mouseExited(with event: NSEvent) {
        if didMakeKey {
            window?.resignKey()
            didMakeKey = false
        }
    }

    override func mouseMoved(with event: NSEvent) {
        if let c = edgeCursor(at: convert(event.locationInWindow, from: nil)) {
            c.set()
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if let c = edgeCursor(at: convert(event.locationInWindow, from: nil)) {
            c.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard frame.contains(point) else { return nil }
        let local = convert(point, from: superview)
        let b = bounds
        let inEdge = local.x < edge || local.x > b.width - edge
                  || local.y < edge || local.y > b.height - edge
        return inEdge ? self : nil
    }
}
