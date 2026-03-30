import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    private let onRecordStart: () -> Void
    private let onRecordStop: () -> Void
    private var isHeld = false
    private var globalKeyDown: Any?
    private var globalKeyUp: Any?
    private var globalFlags: Any?
    private var localKeyDown: Any?
    private var localKeyUp: Any?
    private var localFlags: Any?

    static let keyCodeKey   = "hotkeyKeyCode"
    static let modifiersKey = "hotkeyModifiers"
    static let charKey      = "hotkeyChar"

    // Read live from UserDefaults so updates take effect without re-registering
    private var triggerKeyCode: UInt16 {
        guard UserDefaults.standard.object(forKey: HotkeyManager.keyCodeKey) != nil else {
            return UInt16(kVK_ANSI_D)
        }
        return UInt16(UserDefaults.standard.integer(forKey: HotkeyManager.keyCodeKey))
    }

    private var requiredModifiers: NSEvent.ModifierFlags {
        guard UserDefaults.standard.object(forKey: HotkeyManager.modifiersKey) != nil else {
            return [.control, .option]
        }
        let mods = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: HotkeyManager.modifiersKey)))
        return mods.isEmpty ? [.control, .option] : mods
    }

    static func displayString() -> String {
        let mods: NSEvent.ModifierFlags
        if UserDefaults.standard.object(forKey: modifiersKey) != nil {
            let storedMods = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: modifiersKey)))
            mods = storedMods.isEmpty ? [.control, .option] : storedMods
        } else {
            mods = [.control, .option]
        }
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

        let handleKeyUp: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.isHeld else { return }
            if event.keyCode == self.triggerKeyCode {
                self.isHeld = false
                self.onRecordStop()
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
        globalKeyUp   = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: handleKeyUp)
        globalFlags   = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlags)

        localKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event); return event
        }
        localKeyUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            handleKeyUp(event); return event
        }
        localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlags(event); return event
        }

        print("[Yell] Hotkey registered: \(HotkeyManager.displayString()) (hold to record)")
        print("[Yell] Accessibility trusted: \(AXIsProcessTrusted())")
    }

    deinit {
        for m in [globalKeyDown, globalKeyUp, globalFlags, localKeyDown, localKeyUp, localFlags] {
            if let m { NSEvent.removeMonitor(m) }
        }
    }
}
