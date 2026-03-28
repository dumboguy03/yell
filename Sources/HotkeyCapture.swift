import AppKit
import Carbon.HIToolbox

class HotkeyCapture: NSPanel {
    var onCapture: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?
    private var monitor: Any?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Set Hotkey"
        isFloatingPanel = true
        isReleasedWhenClosed = false

        let prompt = NSTextField(labelWithString: "Hold modifiers + press a key")
        prompt.frame = NSRect(x: 20, y: 38, width: 240, height: 20)
        prompt.alignment = .center
        contentView?.addSubview(prompt)

        let hint = NSTextField(labelWithString: "Escape to cancel — at least one modifier required")
        hint.frame = NSRect(x: 20, y: 14, width: 240, height: 16)
        hint.alignment = .center
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        contentView?.addSubview(hint)
    }

    func show() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.close()
                return nil
            }
            let mods = event.modifierFlags.intersection([.control, .option, .command, .shift])
            guard !mods.isEmpty else { return nil }
            let char = event.charactersIgnoringModifiers?.uppercased() ?? "?"
            self.onCapture?(event.keyCode, mods, char)
            self.close()
            return nil
        }
    }

    override func close() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        super.close()
    }
}
