import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let audioRecorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let keyboardInjector = KeyboardInjector()
    private var hotkeyManager: HotkeyManager!
    private var isRecording = false
    private var isTranscribing = false
    private var isSwitchingModel = false

    // Menu item refs for dynamic updates
    private var hotkeyLabelItem: NSMenuItem!
    private var micStatusItem: NSMenuItem!
    private var axStatusItem: NSMenuItem!
    private var tinyModelItem: NSMenuItem!
    private var baseModelItem: NSMenuItem!
    private var smallModelItem: NSMenuItem!
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

        smallModelItem = NSMenuItem(title: downloadableModelTitle(file: "ggml-small.en.bin", label: "Small (~466MB)"), action: #selector(selectModel(_:)), keyEquivalent: "")
        smallModelItem.representedObject = "ggml-small.en.bin"
        smallModelItem.state = "ggml-small.en.bin" == current ? .on : .off
        modelMenu.addItem(smallModelItem)

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

    private var currentModelFile: String {
        UserDefaults.standard.string(forKey: Transcriber.modelKey) ?? Transcriber.defaultModel
    }

    private var modelItems: [NSMenuItem] {
        [tinyModelItem, baseModelItem, smallModelItem].compactMap { $0 }
    }

    private func downloadableModelTitle(file: String, label: String) -> String {
        modelExists(file) ? label : "\(label) — Download"
    }

    private func refreshModelMenu(selectedFile: String? = nil, useCurrentSelection: Bool = true) {
        tinyModelItem.title = "Tiny (faster)"
        baseModelItem.title = downloadableModelTitle(file: "ggml-base.en.bin", label: "Base")
        smallModelItem.title = downloadableModelTitle(file: "ggml-small.en.bin", label: "Small (~466MB)")

        let file = useCurrentSelection ? (selectedFile ?? currentModelFile) : selectedFile
        modelItems.forEach { item in
            item.state = (file != nil && item.representedObject as? String == file) ? .on : .off
            item.isEnabled = !isSwitchingModel
        }
    }

    private func beginModelOperation(statusTitle: String, on item: NSMenuItem) {
        isSwitchingModel = true
        modelItems.forEach { $0.isEnabled = false }
        item.title = statusTitle
    }

    private func endModelOperation(selectedFile: String? = nil, useCurrentSelection: Bool = true) {
        isSwitchingModel = false
        refreshModelMenu(selectedFile: selectedFile, useCurrentSelection: useCurrentSelection)
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard !isSwitchingModel else { return }
        guard let file = sender.representedObject as? String else { return }
        let previousFile = currentModelFile
        guard file != previousFile else { return }

        if !modelExists(file) {
            let alert = NSAlert()
            alert.messageText = "Download \(file)?"
            alert.informativeText = "The model will be downloaded and saved to ~/.yell/models/."
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            downloadModel(file: file, menuItem: sender, previousFile: previousFile)
            return
        }

        switchModel(to: file, selecting: sender, previousFile: previousFile)
    }

    private func switchModel(to file: String, selecting item: NSMenuItem, previousFile: String, beginOperation: Bool = true) {
        let baseLabel = item.title.components(separatedBy: " —").first ?? item.title
        if beginOperation {
            beginModelOperation(statusTitle: "\(baseLabel) — Loading…", on: item)
        }

        UserDefaults.standard.set(file, forKey: Transcriber.modelKey)
        transcriber.reload { [weak self] success in
            guard let self else { return }
            guard success else {
                self.restorePreviousModel(previousFile, afterFailingToLoad: file)
                return
            }
            self.endModelOperation(selectedFile: file)
        }
    }

    private func restorePreviousModel(_ previousFile: String, afterFailingToLoad attemptedFile: String) {
        UserDefaults.standard.set(previousFile, forKey: Transcriber.modelKey)
        transcriber.reload { [weak self] restored in
            guard let self else { return }
            self.showModelSwitchFailedAlert(file: attemptedFile, restoredPreviousModel: restored)
            self.endModelOperation(selectedFile: restored ? previousFile : nil, useCurrentSelection: restored)
        }
    }

    private func downloadModel(file: String, menuItem: NSMenuItem, previousFile: String) {
        let baseLabel = menuItem.title.components(separatedBy: " —").first ?? menuItem.title
        beginModelOperation(statusTitle: "\(baseLabel) — Downloading…", on: menuItem)

        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(file)") else {
            endModelOperation(selectedFile: previousFile)
            showModelDownloadFailedAlert(file: file, details: "Invalid download URL.")
            return
        }

        URLSession.shared.downloadTask(with: url) { [weak self] tmpURL, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                let httpStatus = (response as? HTTPURLResponse)?.statusCode
                guard error == nil, let tmpURL, httpStatus == 200 else {
                    self.endModelOperation(selectedFile: previousFile)
                    let details = httpStatus.map { "Server responded with HTTP \($0)." }
                    self.showModelDownloadFailedAlert(file: file, details: details)
                    return
                }

                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let destDir = "\(home)/.yell/models"
                let dest = URL(fileURLWithPath: "\(destDir)/\(file)")

                do {
                    try FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.moveItem(at: tmpURL, to: dest)
                } catch {
                    self.endModelOperation(selectedFile: previousFile)
                    self.showModelDownloadFailedAlert(file: file, details: error.localizedDescription)
                    return
                }

                self.switchModel(to: file, selecting: menuItem, previousFile: previousFile, beginOperation: false)
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
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startRecording()
            }
            return
        }
        guard !isRecording, !isTranscribing, !isSwitchingModel else { return }
        isRecording = true
        updateIcon(recording: true)
        audioRecorder.startRecording()
    }

    private func stopRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.stopRecording()
            }
            return
        }
        guard isRecording else { return }
        isRecording = false
        updateIcon(recording: false)

        let samples = audioRecorder.stopRecording()
        guard !samples.isEmpty else { return }

        isTranscribing = true
        transcriber.transcribe(samples: samples) { [weak self] text in
            guard let self else { return }
            self.isTranscribing = false
            guard !text.isEmpty else { return }
            // KeyboardInjector posts CGEvents and does not touch AppKit, so it can run off-main.
            self.keyboardInjector.type(text)
        }
    }

    // MARK: - Alerts

    private func showModelMissingAlert() {
        let alert = NSAlert()
        alert.messageText = "Whisper Model Not Found"
        alert.informativeText = "Run ./download-model.sh to fetch the models."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func showModelSwitchFailedAlert(file: String, restoredPreviousModel: Bool) {
        let alert = NSAlert()
        alert.messageText = "Could not switch to \(file)"
        alert.informativeText = restoredPreviousModel
            ? "Yell kept using the previous model."
            : "Yell could not restore the previous model. Restart the app or re-download the model."
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showModelDownloadFailedAlert(file: String, details: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "Download failed for \(file)"
        alert.informativeText = details ?? "Check your network connection and try again."
        alert.alertStyle = .warning
        alert.runModal()
    }
}
