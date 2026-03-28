import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    private let onRecordStart: () -> Void
    private let onRecordStop: () -> Void
    private var isHeld = false
    private var globalKeyDown: Any?
    private var globalFlags: Any?
    private var localKeyDown: Any?
    private var localFlags: Any?

    static let keyCodeKey   = "hotkeyKeyCode"
    static let modifiersKey = "hotkeyModifiers"
    static let charKey      = "hotkeyChar"

    // Read live from UserDefaults so updates take effect without re-registering
    private var triggerKeyCode: UInt16 {
        let v = UserDefaults.standard.integer(forKey: HotkeyManager.keyCodeKey)
        return v != 0 ? UInt16(v) : UInt16(kVK_ANSI_D)
    }

    private var requiredModifiers: NSEvent.ModifierFlags {
        let v = UserDefaults.standard.integer(forKey: HotkeyManager.modifiersKey)
        return v != 0 ? NSEvent.ModifierFlags(rawValue: UInt(v)) : [.control, .option]
    }

    static func displayString() -> String {
        let storedMods = UserDefaults.standard.integer(forKey: modifiersKey)
        let mods = storedMods != 0
            ? NSEvent.ModifierFlags(rawValue: UInt(storedMods))
            : NSEvent.ModifierFlags([.control, .option])
        let char = UserDefaults.standard.string(forKey: charKey) ?? "D"
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s + char
    }

    init(onRecordStart: @escaping () -> Void, onRecordStop: @escaping () -> Void) {
        self.onRecordStart = onRecordStart
        self.onRecordStop = onRecordStop
    }

    func register() {
        let handleKeyDown: (NSEvent) -> Void = { [weak self] event in
            guard let self, !self.isHeld else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == self.triggerKeyCode && mods.contains(self.requiredModifiers) {
                self.isHeld = true
                self.onRecordStart()
            }
        }

        let handleFlags: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.isHeld else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !mods.contains(self.requiredModifiers) {
                self.isHeld = false
                self.onRecordStop()
            }
        }

        globalKeyDown = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handleKeyDown)
        globalFlags   = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlags)

        localKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event); return event
        }
        localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlags(event); return event
        }

        print("[Yell] Hotkey registered: \(HotkeyManager.displayString()) (hold to record)")
        print("[Yell] Accessibility trusted: \(AXIsProcessTrusted())")
    }

    deinit {
        for m in [globalKeyDown, globalFlags, localKeyDown, localFlags] {
            if let m { NSEvent.removeMonitor(m) }
        }
    }
}
