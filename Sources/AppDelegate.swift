import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let audioRecorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let keyboardInjector = KeyboardInjector()
    private var hotkeyManager: HotkeyManager!
    private var isRecording = false

    // Menu item refs for dynamic updates
    private var hotkeyLabelItem: NSMenuItem!
    private var micStatusItem: NSMenuItem!
    private var axStatusItem: NSMenuItem!
    private var tinyModelItem: NSMenuItem!
    private var baseModelItem: NSMenuItem!
    private var hotkeyCapture: HotkeyCapture?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        if !transcriber.loadModel() {
            showModelMissingAlert()
            return
        }

        hotkeyManager = HotkeyManager(
            onRecordStart: { [weak self] in self?.startRecording() },
            onRecordStop:  { [weak self] in self?.stopRecording() }
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
        menu.delegate = self

        hotkeyLabelItem = NSMenuItem(title: hotkeyLabel(), action: nil, keyEquivalent: "")
        menu.addItem(hotkeyLabelItem)
        menu.addItem(NSMenuItem(title: "Set Hotkey…", action: #selector(setHotkey), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Model submenu
        let current = UserDefaults.standard.string(forKey: Transcriber.modelKey) ?? Transcriber.defaultModel
        let modelMenu = NSMenu()

        tinyModelItem = NSMenuItem(title: "Tiny (faster)", action: #selector(selectModel(_:)), keyEquivalent: "")
        tinyModelItem.representedObject = "ggml-tiny.en.bin"
        tinyModelItem.state = "ggml-tiny.en.bin" == current ? .on : .off
        modelMenu.addItem(tinyModelItem)

        baseModelItem = NSMenuItem(title: downloadableModelTitle(file: "ggml-base.en.bin", label: "Base"), action: #selector(selectModel(_:)), keyEquivalent: "")
        baseModelItem.representedObject = "ggml-base.en.bin"
        baseModelItem.state = "ggml-base.en.bin" == current ? .on : .off
        modelMenu.addItem(baseModelItem)

        let smallItem = NSMenuItem(title: downloadableModelTitle(file: "ggml-small.en.bin", label: "Small (~466MB)"), action: #selector(selectModel(_:)), keyEquivalent: "")
        smallItem.representedObject = "ggml-small.en.bin"
        smallItem.state = "ggml-small.en.bin" == current ? .on : .off
        modelMenu.addItem(smallItem)

        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        menu.addItem(modelItem)
        menu.setSubmenu(modelMenu, for: modelItem)
        menu.addItem(NSMenuItem.separator())

        // Permission status
        micStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        axStatusItem  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(micStatusItem)
        menu.addItem(axStatusItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        refreshPermissionItems()
    }

    private func refreshPermissionItems() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micStatusItem.title  = "Microphone: Granted"
            micStatusItem.action = nil
        case .denied, .restricted:
            micStatusItem.title  = "⚠️ Microphone: Click to Enable"
            micStatusItem.action = #selector(openMicSettings)
        default: // .notDetermined
            micStatusItem.title  = "Microphone: Click to Grant"
            micStatusItem.action = #selector(requestMicPermission)
        }

        let axGranted = AXIsProcessTrusted()
        axStatusItem.title  = axGranted ? "Accessibility: Granted" : "⚠️ Accessibility: Click to Enable"
        axStatusItem.action = axGranted ? nil : #selector(openAxSettings)
    }

    @objc private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.refreshPermissionItems()
            }
        }
    }

    @objc private func openMicSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    @objc private func openAxSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: - Hotkey

    private func hotkeyLabel() -> String {
        "Hold \(HotkeyManager.displayString()) to dictate"
    }

    @objc private func setHotkey() {
        hotkeyCapture = HotkeyCapture()
        hotkeyCapture?.onCapture = { [weak self] keyCode, mods, char in
            guard let self else { return }
            UserDefaults.standard.set(Int(keyCode),       forKey: HotkeyManager.keyCodeKey)
            UserDefaults.standard.set(Int(mods.rawValue), forKey: HotkeyManager.modifiersKey)
            UserDefaults.standard.set(char,               forKey: HotkeyManager.charKey)
            self.hotkeyLabelItem.title = self.hotkeyLabel()
        }
        hotkeyCapture?.show()
    }

    // MARK: - Model Selection

    private func modelExists(_ file: String) -> Bool {
        if Bundle.main.path(forResource: file, ofType: nil) != nil { return true }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return FileManager.default.fileExists(atPath: "\(home)/.yell/models/\(file)")
    }

    private func downloadableModelTitle(file: String, label: String) -> String {
        modelExists(file) ? label : "\(label) — Download"
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let file = sender.representedObject as? String else { return }

        if !modelExists(file) {
            let alert = NSAlert()
            alert.messageText = "Download \(file)?"
            alert.informativeText = "The model will be downloaded and saved to ~/.yell/models/."
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            downloadModel(file: file, menuItem: sender)
            return
        }

        switchModel(to: file, selecting: sender)
    }

    private func switchModel(to file: String, selecting item: NSMenuItem) {
        UserDefaults.standard.set(file, forKey: Transcriber.modelKey)
        guard transcriber.reload() else {
            showModelMissingAlert()
            return
        }
        [tinyModelItem, baseModelItem].forEach { $0?.state = .off }
        // also clear any other model items
        item.menu?.items.forEach { $0.state = .off }
        item.state = .on
    }

    private func downloadModel(file: String, menuItem: NSMenuItem) {
        let baseLabel = menuItem.title.components(separatedBy: " —").first ?? menuItem.title
        menuItem.title = "\(baseLabel) — Downloading…"
        menuItem.isEnabled = false

        let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(file)")!
        URLSession.shared.downloadTask(with: url) { [weak self] tmpURL, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                menuItem.isEnabled = true
                guard error == nil, let tmpURL else {
                    menuItem.title = "\(baseLabel) — Download Failed"
                    return
                }
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let destDir = "\(home)/.yell/models"
                let dest = URL(fileURLWithPath: "\(destDir)/\(file)")
                try? FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
                try? FileManager.default.moveItem(at: tmpURL, to: dest)
                menuItem.title = baseLabel
                self.switchModel(to: file, selecting: menuItem)
            }
        }.resume()
    }

    // MARK: - Icon

    func updateIcon(recording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusItem.button else { return }
            button.image = NSImage(systemSymbolName: recording ? "mic.fill" : "mic", accessibilityDescription: "Yell")
            button.contentTintColor = recording ? .systemRed : nil
        }
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        updateIcon(recording: true)
        audioRecorder.startRecording()
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        updateIcon(recording: false)

        let samples = audioRecorder.stopRecording()
        guard !samples.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let text = self.transcriber.transcribe(samples: samples)
            guard !text.isEmpty else { return }
            DispatchQueue.main.async { self.keyboardInjector.type(text) }
        }
    }

    // MARK: - Alerts

    private func showModelMissingAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Whisper Model Not Found"
            alert.informativeText = "Run ./download-model.sh to fetch the models."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}
