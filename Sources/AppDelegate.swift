import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let audioRecorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let keyboardInjector = KeyboardInjector()
    private var hotkeyManager: HotkeyManager!
    private var isRecording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        checkAccessibility()

        if !transcriber.loadModel() {
            showModelMissingAlert()
            return
        }

        hotkeyManager = HotkeyManager(
            onRecordStart: { [weak self] in self?.startRecording() },
            onRecordStop: { [weak self] in self?.stopRecording() }
        )
        hotkeyManager.register()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Yell")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Yell — Hold ⌃⌥D to dictate", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func updateIcon(recording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusItem.button else { return }
            if recording {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Recording")
                button.contentTintColor = .systemRed
            } else {
                button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Yell")
                button.contentTintColor = nil
            }
        }
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        updateIcon(recording: true)
        audioRecorder.startRecording()
        print("[Yell] 🔴 Recording...")
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        updateIcon(recording: false)

        let samples = audioRecorder.stopRecording()
        print("[Yell] ⏹ Stopped. Got \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000))s of audio)")
        guard !samples.isEmpty else {
            print("[Yell] No audio captured")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            print("[Yell] Transcribing...")
            let text = self.transcriber.transcribe(samples: samples)
            print("[Yell] Result: \"\(text)\"")
            guard !text.isEmpty else { return }
            DispatchQueue.main.async {
                self.keyboardInjector.type(text)
            }
        }
    }

    // MARK: - Permissions

    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("⚠️  Accessibility permission required for keyboard injection. Please grant it in System Settings → Privacy & Security → Accessibility.")
        }
    }

    private func showModelMissingAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Whisper Model Not Found"
            alert.informativeText = "Download ggml-base.en.bin to ~/.yell/models/\n\nRun: ./download-model.sh"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}
