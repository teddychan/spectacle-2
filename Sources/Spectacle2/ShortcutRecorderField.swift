import SwiftUI
import AppKit
import Carbon.HIToolbox
import SpectacleCore

/// A click-to-record control: shows the current shortcut; while recording, the next key combo
/// (with ≥1 modifier) becomes the new Shortcut. Esc cancels; Delete clears.
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: Shortcut?
    var onChange: (Shortcut?) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let b = RecorderButton()
        b.onCapture = { sc in shortcut = sc; onChange(sc) }
        return b
    }
    func updateNSView(_ nsView: RecorderButton, context: Context) { nsView.shortcut = shortcut }

    final class RecorderButton: NSButton {
        var shortcut: Shortcut? { didSet { title = display } }
        var onCapture: ((Shortcut?) -> Void)?
        private var recording = false { didSet { title = display } }

        override init(frame: NSRect) {
            super.init(frame: frame)
            bezelStyle = .rounded
            setButtonType(.momentaryPushIn)
            target = self; action = #selector(toggle)
        }
        required init?(coder: NSCoder) { fatalError() }

        private var display: String {
            recording ? "Recording… (Esc to cancel)" : (shortcut?.displayString ?? "Click to record")
        }

        @objc private func toggle() { recording.toggle(); if recording { window?.makeFirstResponder(self) } }
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == UInt16(kVK_Escape) { recording = false; return }
            if event.keyCode == UInt16(kVK_Delete) { shortcut = nil; onCapture?(nil); recording = false; return }
            let mods = Self.modifierFlags(from: event.modifierFlags)
            guard !mods.isEmpty else { NSSound.beep(); return }   // require a modifier
            let sc = Shortcut(keyCode: event.keyCode, modifiers: mods)
            shortcut = sc; onCapture?(sc); recording = false
        }

        static func modifierFlags(from ns: NSEvent.ModifierFlags) -> ModifierFlags {
            var m: ModifierFlags = []
            if ns.contains(.command) { m.insert(.command) }
            if ns.contains(.option)  { m.insert(.option) }
            if ns.contains(.control) { m.insert(.control) }
            if ns.contains(.shift)   { m.insert(.shift) }
            return m
        }
    }
}
