import AppKit

// Prevent multiple instances
let bundleID = Bundle.main.bundleIdentifier ?? "com.yell.app"
if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
