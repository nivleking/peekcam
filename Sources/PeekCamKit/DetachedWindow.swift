import AppKit
import PeekCamCore

/// The preview as a small floating window: stays in front, on every Space, drag anywhere to move,
/// resize keeps the aspect ratio.
@MainActor
final class DetachedWindow: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    var onClose: ((CGRect) -> Void)?

    var isShown: Bool { panel?.isVisible == true }

    func show(_ content: PreviewContentView, frame: CGRect, aspect: AspectRatio) {
        let panel = panel ?? makePanel()
        self.panel = panel
        content.isDetached = true
        panel.contentView = content
        panel.contentAspectRatio = NSSize(width: aspect.ratio, height: 1)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(content)
    }

    func close() { panel?.close() }

    func windowWillClose(_ notification: Notification) {
        guard let panel else { return }
        let frame = panel.frame
        panel.contentView = nil
        // Dropped, not kept hidden: a closed preview should hold no window memory.
        self.panel = nil
        onClose?(frame)
    }

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(contentRect: .zero,
                                 styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .black
        panel.minSize = NSSize(width: 160, height: 90)
        panel.delegate = self
        return panel
    }
}

/// A non-activating panel still has to take key events for Space (snap) and Escape.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
