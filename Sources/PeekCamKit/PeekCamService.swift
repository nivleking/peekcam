import AppKit
import AVFoundation
import PeekCamCore

/// Everything PeekCam does, behind one small API, so it can run on its own (the PeekCam
/// app) or as one module inside KTools (one menu bar icon for all of Kelvin's tools).
///
/// The host owns the status item. PeekCam registers its hot key, shows the preview,
/// and fills a menu.
@MainActor
public final class PeekCamService: NSObject {
    public private(set) var settings = AppSettings()
    /// Where the preview hangs from when opened by the hot key. Nil = under the cursor.
    public weak var anchorButton: NSStatusBarButton?
    private let camera: CameraSession = AVCameraSession()
    private lazy var content: PreviewContentView = {
        let view = PreviewContentView(layer: camera.previewLayer)
        view.onSnap = { [weak self] in self?.snap() }
        view.onToggleDetach = { [weak self] in self?.toggleDetached() }
        view.onClose = { [weak self] in self?.closePreview() }
        return view
    }()
    private lazy var preview: PreviewPopover = {
        let p = PreviewPopover()
        p.onClose = { [weak self] in self?.previewClosed() }
        return p
    }()
    private lazy var window: DetachedWindow = {
        let w = DetachedWindow()
        w.onClose = { [weak self] frame in
            self?.update { $0.detachedFrame = [frame.minX, frame.minY, frame.width, frame.height] }
            self?.previewClosed()
        }
        return w
    }()
    /// True while the preview moves between popover and window, so the camera keeps running.
    private var handingOver = false
    private var hotKey: GlobalHotKey?
    private var started = false

    public override init() {
        super.init()
    }

    /// Loads settings and registers the hot key. The camera stays off until the preview opens.
    public func start() {
        settings = AppSettings.load(from: AppPaths.dataDirectory)
        started = true
        registerHotKey()
    }

    public func stop() {
        closePreview()
        hotKey = nil
        started = false
    }

    public var isPreviewVisible: Bool { preview.isShown || window.isShown }

    /// "⌃⇧M", for menus.
    public var hotKeyDisplay: String { settings.hotKeySpec.display }

    /// True when another app already owns the shortcut.
    public var hotKeyFailed: Bool { started && hotKey == nil }

    /// Changes the shortcut (text like "ctrl+shift+M"). Keeps the old one and returns false when the text is
    /// not a shortcut or another app already owns the new one.
    @discardableResult
    public func updateHotKey(_ text: String) -> Bool {
        guard HotKeySpec(text) != nil else { return false }
        let old = settings.hotKey
        settings.hotKey = text
        registerHotKey()
        if hotKeyFailed {
            settings.hotKey = old
            registerHotKey()
            return false
        }
        try? settings.save(to: AppPaths.dataDirectory)
        return true
    }

    public func togglePreview(from button: NSStatusBarButton? = nil) {
        if isPreviewVisible {
            closePreview()
        } else {
            openPreview(from: button ?? anchorButton)
        }
    }

    private func closePreview() {
        preview.close()
        window.close()
    }

    /// The meter only runs with the setting on and the permission granted.
    private var micActive: Bool {
        settings.micCheck && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func applyPreviewOptions() {
        content.lighting = settings.lighting
        content.showsMeter = micActive
        camera.onLevel = { [weak self] level in self?.content.setLevel(level) }
    }

    private func previewClosed() {
        // NSPopover may report its close after the window already took the picture over.
        if !handingOver && !isPreviewVisible { camera.stop() }
    }

    private func openPreview(from button: NSStatusBarButton?) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else { return }
                Task { @MainActor in self.openPreview(from: button) }
            }
            return
        default:
            openCameraPrivacySettings()
            return
        }
        guard let chosen = CameraPicker.choose(preferred: settings.cameraID, from: AVCameraSession.cameras) else {
            NSLog("PeekCam: no camera found")
            return
        }
        let size = settings.previewSize
        applyPreviewOptions()
        preview.show(content, size: NSSize(width: size.width, height: size.height), from: button)
        camera.start(camera: chosen, mirror: settings.mirror, microphone: micActive)
    }

    /// Moves the running preview between the menu bar popover and the floating window.
    private func toggleDetached() {
        handingOver = true
        defer { handingOver = false }
        if window.isShown {
            window.close()
            let size = settings.previewSize
            preview.show(content, size: NSSize(width: size.width, height: size.height), from: anchorButton)
        } else {
            preview.close()
            showWindow()
        }
    }

    private func showWindow() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let frame = WindowPlacement.frame(saved: settings.detachedRect, defaultWidth: settings.size.width,
                                          aspect: settings.aspect, visible: screen.visibleFrame)
        window.show(content, frame: frame, aspect: settings.aspect)
    }

    /// Saves a PNG (and copies it) of what the preview shows, with a white flash.
    public func snap() {
        guard isPreviewVisible else { return }
        let settings = settings
        camera.capturePhoto { [weak self] image in
            guard let image, Snapper.save(image, mirrored: settings.mirror, settings: settings) != nil else {
                NSSound.beep()
                return
            }
            self?.content.flash()
            NSSound(named: "Tink")?.play()
        }
    }

    private func registerHotKey() {
        hotKey = nil
        hotKey = GlobalHotKey(settings.hotKeySpec) { [weak self] in
            Task { @MainActor in self?.togglePreview() }
        }
        if hotKey == nil {
            NSLog("PeekCam: \(settings.hotKeySpec.display) is already used by another app")
        }
    }

    private func update(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        try? settings.save(to: AppPaths.dataDirectory)
    }

    // MARK: - Menu

    /// Appends PeekCam's menu items (no Quit: that belongs to the host app).
    public func fillMenu(_ menu: NSMenu) {
        if hotKeyFailed {
            menu.addItem(withTitle: "⚠︎ \(hotKeyDisplay) is used by another app (change hotKey in settings.json)",
                         action: nil, keyEquivalent: "")
        }
        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            add(to: menu, "⚠︎ Allow Camera Access…", #selector(openCameraPrivacySettings))
        }
        add(to: menu, "Show Camera    \(hotKeyDisplay)", #selector(toggleFromMenu))
        if isPreviewVisible {
            add(to: menu, "Snap Photo    Space", #selector(snapFromMenu))
            add(to: menu, window.isShown ? "Back to Menu Bar" : "Detach Window", #selector(detachFromMenu))
        }
        menu.addItem(.separator())

        let cameras = AVCameraSession.cameras
        let current = CameraPicker.choose(preferred: settings.cameraID, from: cameras)
        let cameraMenu = NSMenu()
        for info in cameras {
            let item = add(to: cameraMenu, info.name, #selector(chooseCamera(_:)))
            item.representedObject = info.id
            item.state = info.id == current?.id ? .on : .off
        }
        if cameras.isEmpty { cameraMenu.addItem(withTitle: "No Camera Found", action: nil, keyEquivalent: "") }
        menu.addItem(withTitle: "Camera", action: nil, keyEquivalent: "").submenu = cameraMenu

        let sizeMenu = NSMenu()
        for preset in SizePreset.allCases {
            let item = add(to: sizeMenu, preset.title, #selector(chooseSize(_:)))
            item.representedObject = preset.rawValue
            item.state = preset == settings.size ? .on : .off
        }
        sizeMenu.addItem(.separator())
        for aspect in AspectRatio.allCases {
            let item = add(to: sizeMenu, aspect.title, #selector(chooseAspect(_:)))
            item.representedObject = aspect.rawValue
            item.state = aspect == settings.aspect ? .on : .off
        }
        menu.addItem(withTitle: "Size", action: nil, keyEquivalent: "").submenu = sizeMenu

        add(to: menu, "Mirror", #selector(toggleMirror)).state = settings.mirror ? .on : .off
        add(to: menu, "Lighting", #selector(toggleLighting)).state = settings.lighting ? .on : .off
        add(to: menu, "Mic Check", #selector(toggleMicCheck)).state = settings.micCheck ? .on : .off
        let login = add(to: menu, LaunchAtLogin.needsApproval ? "Launch at Login (approve in System Settings)" : "Launch at Login",
                        #selector(toggleLaunchAtLogin))
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(.separator())
        add(to: menu, "Open Snaps Folder", #selector(openSnapsFolder))
        add(to: menu, "Edit settings.json…", #selector(openSettingsFile))
        add(to: menu, "Reload Settings", #selector(reloadSettings))
    }

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func toggleFromMenu() {
        // Wait for the menu to close, or the transient popover closes right away.
        DispatchQueue.main.async { [weak self] in self?.togglePreview() }
    }

    @objc private func snapFromMenu() { snap() }
    @objc private func detachFromMenu() { DispatchQueue.main.async { [weak self] in self?.toggleDetached() } }

    @objc private func openSnapsFolder() {
        try? FileManager.default.createDirectory(at: settings.saveDirectoryURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(settings.saveDirectoryURL)
    }

    @objc private func chooseCamera(_ sender: NSMenuItem) {
        update { $0.cameraID = sender.representedObject as? String }
        restartIfVisible()
    }

    @objc private func chooseSize(_ sender: NSMenuItem) {
        guard let preset = SizePreset(rawValue: sender.representedObject as? String ?? "") else { return }
        update { $0.size = preset }
        restartIfVisible()
    }

    @objc private func chooseAspect(_ sender: NSMenuItem) {
        guard let aspect = AspectRatio(rawValue: sender.representedObject as? String ?? "") else { return }
        update { $0.aspect = aspect }
        restartIfVisible()
    }

    @objc private func toggleMirror() {
        update { $0.mirror.toggle() }
        camera.setMirror(settings.mirror)
    }

    @objc private func toggleLighting() {
        update { $0.lighting.toggle() }
        content.lighting = settings.lighting
    }

    @objc private func toggleMicCheck() {
        if settings.micCheck {
            update { $0.micCheck = false }
            restartIfVisible()
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            update { $0.micCheck = true }
            restartIfVisible()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                guard granted else { return }
                Task { @MainActor in
                    self.update { $0.micCheck = true }
                    self.restartIfVisible()
                }
            }
        default:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    private func restartIfVisible() {
        if window.isShown {
            // Stay detached: new camera and shape in place.
            if let chosen = CameraPicker.choose(preferred: settings.cameraID, from: AVCameraSession.cameras) {
                applyPreviewOptions()
                camera.start(camera: chosen, mirror: settings.mirror, microphone: micActive)
            }
            handingOver = true
            window.close()
            handingOver = false
            showWindow()
        } else if preview.isShown {
            preview.close()
            DispatchQueue.main.async { [weak self] in self?.togglePreview() }
        }
    }

    @objc private func openSettingsFile() {
        try? settings.save(to: AppPaths.dataDirectory)
        NSWorkspace.shared.open(AppPaths.dataDirectory.appendingPathComponent("settings.json"))
    }

    @objc private func reloadSettings() {
        closePreview()
        start()
    }

    @objc private func openCameraPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
    }
}
