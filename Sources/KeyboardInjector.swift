import CoreGraphics
import Foundation

class KeyboardInjector {
    /// Types text into the currently focused application using CGEvent keyboard injection.
    func type(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text {
            let utf16 = Array(String(char).utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }

            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)

            keyDown.post(tap: .cgAnnotatedSessionEventTap)
            keyUp.post(tap: .cgAnnotatedSessionEventTap)

            usleep(3000) // 3ms between keystrokes to avoid dropped characters
        }
    }
}
