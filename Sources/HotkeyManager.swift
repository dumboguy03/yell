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

    // Ctrl+Option+D
    private let requiredModifiers: NSEvent.ModifierFlags = [.control, .option]
    private let triggerKeyCode: UInt16 = UInt16(kVK_ANSI_D)

    init(onRecordStart: @escaping () -> Void, onRecordStop: @escaping () -> Void) {
        self.onRecordStart = onRecordStart
        self.onRecordStop = onRecordStop
    }

    func register() {
        let handleKeyDown: (NSEvent) -> Void = { [weak self] event in
            guard let self, !self.isHeld else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == self.triggerKeyCode && mods.contains(self.requiredModifiers) {
                print("[Yell] Hotkey detected — recording started")
                self.isHeld = true
                self.onRecordStart()
            }
        }

        let handleFlags: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.isHeld else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !mods.contains(self.requiredModifiers) {
                print("[Yell] Modifiers released — recording stopped")
                self.isHeld = false
                self.onRecordStop()
            }
        }

        // Global monitors (events in other apps — requires Accessibility permission)
        globalKeyDown = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handleKeyDown)
        globalFlags = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handleFlags)

        // Local monitors (events when our own menu is open)
        localKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
            return event
        }
        localFlags = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleFlags(event)
            return event
        }

        print("[Yell] Hotkey registered: Ctrl+Option+D (hold to record, release to transcribe)")
        print("[Yell] Accessibility trusted: \(AXIsProcessTrusted())")
    }

    deinit {
        for m in [globalKeyDown, globalFlags, localKeyDown, localFlags] {
            if let m { NSEvent.removeMonitor(m) }
        }
    }
}
