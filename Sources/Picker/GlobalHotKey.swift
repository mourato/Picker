import Carbon.HIToolbox
import Foundation

// MARK: - Global hotkey
//
// Thin Carbon RegisterEventHotKey wrapper. Does not need Accessibility; the
// system delivers presses to our handler even when another app is focused.

@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onPress: (() -> Void)?

    private static let signature: OSType = 0x504B4852  // 'PKHR'
    private static let hotKeyID = EventHotKeyID(signature: signature, id: 1)

    func register(shortcut: PickShortcut, onPress: @escaping () -> Void) {
        unregister()
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))

        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return noErr }
                var hk = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hk)
                guard err == noErr, hk.signature == GlobalHotKey.signature else {
                    return noErr
                }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hotKey.onPress?() }
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef)

        guard status == noErr else { return }

        var ref: EventHotKeyRef?
        let reg = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            Self.hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref)
        if reg == noErr {
            hotKeyRef = ref
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        onPress = nil
    }
}
