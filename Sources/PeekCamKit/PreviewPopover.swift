import AppKit

/// A popover around the shared `PreviewContentView`, hanging from the menu bar.
@MainActor
final class PreviewPopover: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    /// Invisible window under the cursor, used as the anchor when there is no status item
    /// button (hot key inside KTools).
    private var anchorWindow: NSWindow?
    var onClose: (() -> Void)?

    override init() {
        super.init()
        // Transient: a click anywhere outside closes it.
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
    }

    var isShown: Bool { popover.isShown }

    func show(_ content: PreviewContentView, size: NSSize, from button: NSStatusBarButton?) {
        content.isDetached = false
        content.frame = NSRect(origin: .zero, size: size)
        let controller = NSViewController()
        controller.view = content
        popover.contentViewController = controller
        popover.contentSize = size

        NSApp.activate(ignoringOtherApps: true)
        if let button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            let anchor = makeAnchorUnderMenuBar()
            popover.show(relativeTo: anchor.contentView!.bounds, of: anchor.contentView!, preferredEdge: .minY)
        }
        content.window?.makeFirstResponder(content)
    }

    func close() { popover.close() }

    func popoverDidClose(_ notification: Notification) {
        // Leave the view alone when it already moved into the detached window.
        if !(popover.contentViewController?.view.window is NSPanel) {
            popover.contentViewController = nil
        }
        anchorWindow?.orderOut(nil)
        anchorWindow = nil
        onClose?()
    }

    private func makeAnchorUnderMenuBar() -> NSWindow {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let top = screen.visibleFrame.maxY
        let window = NSWindow(contentRect: NSRect(x: mouse.x, y: top - 1, width: 1, height: 1),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.orderFrontRegardless()
        anchorWindow = window
        return window
    }
}
