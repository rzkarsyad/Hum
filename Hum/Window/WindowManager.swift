import AppKit
import SwiftUI

/// The smallest patch of the window that must stay on screen for the user to be
/// able to grab and drag it back.
let minGrabbableWindowSize = CGSize(width: 120, height: 40)

/// Returns a frame the user can actually reach, given the screens attached now.
///
/// A saved frame can point at a display that has since been unplugged. Hum's
/// panel is borderless, has no Dock icon and no window menu, so a window
/// restored out there cannot be dragged back at all — the app looks like it
/// simply stopped working until its preferences are deleted by hand.
func reachableWindowFrame(saved: CGRect, screens: [CGRect], fallback: CGRect) -> CGRect {
    guard saved.width > 0, saved.height > 0,
          saved.origin.x.isFinite, saved.origin.y.isFinite,
          saved.width.isFinite, saved.height.isFinite
    else { return fallback }

    // Nothing to validate against — moving the window would only be a guess.
    guard !screens.isEmpty else { return saved }

    // Enough of it showing on a screen it actually fits? Leave it exactly where
    // the user put it, including deliberately hanging off an edge.
    for screen in screens where saved.width <= screen.width && saved.height <= screen.height {
        let overlap = saved.intersection(screen)
        guard !overlap.isNull else { continue }
        if overlap.width >= min(minGrabbableWindowSize.width, saved.width),
           overlap.height >= min(minGrabbableWindowSize.height, saved.height) {
            return saved
        }
    }

    // Otherwise bring it onto the screen whose centre is nearest, keeping its
    // size wherever that still fits.
    let target = screens.min {
        hypot($0.midX - saved.midX, $0.midY - saved.midY) <
        hypot($1.midX - saved.midX, $1.midY - saved.midY)
    } ?? screens[0]

    let size = CGSize(width: min(saved.width, target.width),
                      height: min(saved.height, target.height))
    return CGRect(
        x: min(max(saved.minX, target.minX), target.maxX - size.width),
        y: min(max(saved.minY, target.minY), target.maxY - size.height),
        width: size.width,
        height: size.height
    )
}

final class WindowManager: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private var savedHeight: CGFloat = 276
    private var isResizingProgrammatically = false

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
        let headerHeight = HumLayout.headerHeight
        let targetHeight: CGFloat
        if minimized {
            // Remember the expanded height before collapsing (skip if already collapsed).
            if panel.frame.height > headerHeight + 20 {
                savedHeight = panel.frame.height
            }
            targetHeight = headerHeight
        } else {
            targetHeight = savedHeight
        }

        // Top edge stays anchored: the bar collapses/expands from its bottom edge.
        let targetFrame = CGRect(
            x: panel.frame.minX,
            y: panel.frame.maxY - targetHeight,
            width: panel.frame.width,
            height: targetHeight
        )
        animateResize(to: targetFrame)
    }

    // Gentle spring-like resize: glide a little *past* the target with momentum,
    // then settle back onto it — a soft bounce instead of a flat ease. The overshoot
    // is a small fixed amount (not proportional to travel) and clamped so it can
    // never dip far enough to clip the header content. The flag keeps the transient
    // animation frames from being persisted as the saved window frame.
    private func animateResize(to target: NSRect) {
        let anchorMaxY = panel.frame.maxY
        let goingDown = target.height < panel.frame.height
        let bounce: CGFloat = 7
        let overshootHeight = max(
            HumLayout.headerHeight - 8,
            target.height + (goingDown ? -bounce : bounce)
        )
        let overshoot = CGRect(
            x: target.minX,
            y: anchorMaxY - overshootHeight,
            width: target.width,
            height: overshootHeight
        )

        isResizingProgrammatically = true
        // Phase 1: ride to just beyond the target, decelerating.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(overshoot, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            // Phase 2: settle back onto the target.
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.16
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in
                self?.isResizingProgrammatically = false
            })
        })
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        // Ignore the transient frames emitted during the collapse/expand animation.
        guard !isResizingProgrammatically else { return }
        // Don't save when window is in minimized state (header only)
        guard panel.frame.height > 80 else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame")
    }

    private func restoreOrSetDefaultPosition() {
        let size = CGSize(width: 320, height: 276)
        let screens = NSScreen.screens.map(\.visibleFrame)
        let fallback: CGRect = {
            guard let screen = NSScreen.main else { return CGRect(origin: .zero, size: size) }
            return CGRect(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.minY + 60,
                width: size.width,
                height: size.height
            )
        }()

        let saved = UserDefaults.standard.string(forKey: "windowFrame").map(NSRectFromString) ?? .zero
        // Never trust a saved frame blindly: the display it was saved on may be gone.
        let frame = reachableWindowFrame(saved: saved, screens: screens, fallback: fallback)
        panel.setFrame(frame, display: false)
        savedHeight = frame.height
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
        minSize = CGSize(width: 200, height: HumLayout.headerHeight)
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
