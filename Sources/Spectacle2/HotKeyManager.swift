import Carbon.HIToolbox
import SpectacleCore

/// Wraps Carbon RegisterEventHotKey. Translates the core's neutral ModifierFlags → Carbon masks.
/// The fired hot key is mapped back to a WindowAction and delivered on the main actor.
///
/// All mutable state (`refs`, `actionByID`, `handler`) is only ever touched on the main thread:
/// registration happens from the main actor, and Carbon delivers hot-key events on the main run
/// loop via the C callback below. Marked `@unchecked Sendable` because the C callback captures
/// `self` through an unretained opaque pointer, which the compiler cannot verify as isolated.
final class HotKeyManager: @unchecked Sendable {
    private var refs: [EventHotKeyRef?] = []
    private var actionByID: [UInt32: WindowAction] = [:]
    private var handler: EventHandlerRef?
    private let onAction: @Sendable (WindowAction) -> Void

    init(onAction: @escaping @Sendable (WindowAction) -> Void) {
        self.onAction = onAction
        installHandler()
    }

    func register(_ map: [WindowAction: Shortcut]) {
        unregisterAll()
        var nextID: UInt32 = 1
        for action in WindowAction.allCases {
            defer { nextID += 1 }
            guard let sc = map[action] else { continue }
            let hotKeyID = EventHotKeyID(signature: OSType(0x53504332), id: nextID) // 'SPC2'
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(sc.keyCode), carbonMask(sc.modifiers),
                                             hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr { actionByID[nextID] = action; refs.append(ref) }
        }
    }

    func unregisterAll() {
        for r in refs where r != nil { UnregisterEventHotKey(r!) }
        refs.removeAll(); actionByID.removeAll()
    }

    private func carbonMask(_ m: ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if m.contains(.command) { mask |= UInt32(cmdKey) }
        if m.contains(.option)  { mask |= UInt32(optionKey) }
        if m.contains(.control) { mask |= UInt32(controlKey) }
        if m.contains(.shift)   { mask |= UInt32(shiftKey) }
        return mask
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let action = manager.actionByID[hkID.id] { manager.onAction(action) }
            return noErr
        }, 1, &spec, selfPtr, &handler)
    }
}
