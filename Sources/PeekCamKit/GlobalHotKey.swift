import Carbon.HIToolbox
import PeekCamCore

/// System-wide shortcut using Carbon's RegisterEventHotKey.
///
/// Unlike a global key monitor, it needs no Accessibility or Input Monitoring
/// permission: macOS only tells us when this exact combination is pressed.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    private let id: UInt32
    static let signature = OSType(0x504B_434D) // "PKCM"

    /// Fails (returns nil) when another app already owns the combination,
    /// e.g. another camera app.
    convenience init?(_ spec: HotKeySpec, action: @escaping () -> Void) {
        self.init(keyCode: spec.keyCode, modifiers: spec.modifiers, id: 1, action: action)
    }

    /// `id` must be unique per registered key: every hot key in the app reaches every handler.
    init?(keyCode: Int, modifiers: Int, id: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.id = id

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            // Every hot key registered in this process reaches every handler. Inside KTools,
            // other modules (ClipText…) also use id 1, so the signature must match too.
            guard pressed.signature == GlobalHotKey.signature, pressed.id == hotKey.id else {
                return OSStatus(eventNotHandledErr)
            }
            hotKey.action()
            return noErr
        }, 1, &eventType, selfPointer, &handlerRef)
        guard installed == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: id)
        let registered = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                             GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else {
            RemoveEventHandler(handlerRef)
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
