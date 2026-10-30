import AppKit
import PeekCamKit

/// Standalone PeekCam: its own menu bar icon around `PeekCamService`.
/// Left click opens the preview, right click (or ⌃ click) opens the menu.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let service = PeekCamService()
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        service.start()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "person.crop.square", accessibilityDescription: "PeekCam")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            service.anchorButton = button
        }
        menu.delegate = self
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            // Attach the menu only for this click; a permanent menu would swallow left clicks.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            service.togglePreview(from: statusItem.button)
        }
    }

    /// Rebuilt each time it opens, so cameras and warnings are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        service.fillMenu(menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PeekCam", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }
}
