import AppKit

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
// Menu bar only: no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()
