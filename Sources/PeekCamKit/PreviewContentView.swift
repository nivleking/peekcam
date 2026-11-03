import AppKit
import AVFoundation
import PeekCamCore

/// The camera picture plus two small buttons (snap, detach) that show while the mouse is over it.
/// One instance moves between the popover and the detached window, so the camera keeps running.
@MainActor
final class PreviewContentView: NSView {
    var onSnap: (() -> Void)?
    var onToggleDetach: (() -> Void)?
    var onClose: (() -> Void)?

    private let cameraLayer: AVCaptureVideoPreviewLayer
    private let flashLayer = CALayer()
    private let snapButton = PreviewContentView.button("camera.fill", "Snap (Space)")
    private let detachButton = PreviewContentView.button("pip.exit", "Detach")
    private let meterTrack = CALayer()
    private let meterFill = CALayer()
    private static let meterSize = CGSize(width: 90, height: 6)

    init(layer cameraLayer: AVCaptureVideoPreviewLayer) {
        self.cameraLayer = cameraLayer
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        cameraLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(cameraLayer)
        flashLayer.backgroundColor = NSColor.white.cgColor
        flashLayer.opacity = 0
        flashLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(flashLayer)
        meterTrack.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        meterTrack.cornerRadius = 3
        meterTrack.isHidden = true
        meterFill.backgroundColor = NSColor.systemGreen.cgColor
        meterFill.cornerRadius = 3
        meterTrack.addSublayer(meterFill)
        layer?.addSublayer(meterTrack)

        snapButton.target = self
        snapButton.action = #selector(snapClicked)
        detachButton.target = self
        detachButton.action = #selector(detachClicked)
        let stack = NSStackView(views: [snapButton, detachButton])
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
        setButtonsVisible(false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Rounded corners only in the popover; the window has its own.
    var isDetached = false {
        didSet {
            layer?.cornerRadius = isDetached ? 0 : 10
            detachButton.image = NSImage(systemSymbolName: isDetached ? "pip.enter" : "pip.exit", accessibilityDescription: nil)
            detachButton.toolTip = isDetached ? "Back to menu bar" : "Detach"
        }
    }

    /// A bright frame around the picture (see `LightingFrame`).
    var lighting = false {
        didSet {
            layer?.backgroundColor = (lighting ? NSColor.white : NSColor.black).cgColor
            needsLayout = true
        }
    }

    /// Shows the microphone meter while true.
    var showsMeter = false {
        didSet {
            meterTrack.isHidden = !showsMeter
            if !showsMeter { setLevel(0) }
        }
    }

    func setLevel(_ level: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        meterFill.frame = CGRect(x: 0, y: 0, width: Self.meterSize.width * min(max(level, 0), 1), height: Self.meterSize.height)
        meterFill.backgroundColor = (level > 0.9 ? NSColor.systemRed : level > 0.75 ? NSColor.systemYellow : NSColor.systemGreen).cgColor
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cameraLayer.frame = lighting ? LightingFrame.cameraRect(in: bounds, thickness: LightingFrame.defaultThickness) : bounds
        cameraLayer.cornerRadius = lighting ? 8 : 0
        cameraLayer.masksToBounds = lighting
        flashLayer.frame = bounds
        meterTrack.frame = CGRect(origin: CGPoint(x: 10, y: 10), size: Self.meterSize)
        CATransaction.commit()
    }

    func flash() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.9
        animation.toValue = 0
        animation.duration = 0.35
        flashLayer.add(animation, forKey: "flash")
    }

    // MARK: - Mouse and keys

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseEntered(with event: NSEvent) { setButtonsVisible(true) }
    override func mouseExited(with event: NSEvent) { setButtonsVisible(false) }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49: onSnap?() // Space
        case 53: onClose?() // Escape
        default: super.keyDown(with: event)
        }
    }

    private func setButtonsVisible(_ visible: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            snapButton.animator().alphaValue = visible ? 1 : 0
            detachButton.animator().alphaValue = visible ? 1 : 0
        }
    }

    @objc private func snapClicked() { onSnap?() }
    @objc private func detachClicked() { onToggleDetach?() }

    private static func button(_ symbol: String, _ tip: String) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip)!, target: nil, action: nil)
        b.bezelStyle = .circular
        b.isBordered = true
        b.contentTintColor = .white
        b.toolTip = tip
        b.wantsLayer = true
        b.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        b.layer?.cornerRadius = 14
        b.isBordered = false
        b.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([b.widthAnchor.constraint(equalToConstant: 28), b.heightAnchor.constraint(equalToConstant: 28)])
        return b
    }
}
