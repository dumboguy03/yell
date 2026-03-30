# Yell

![License](https://img.shields.io/github/license/dumboguy03/yell) ![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
   
<video src="https://github.com/user-attachments/assets/211b90fd-1588-449a-85ce-bb056d8f6445"></video>

Press a hotkey, speak, and your words are typed anywhere — no cloud, no subscription.
- Audio never leaves the device
- Works offline
- Free, open source, auditable
- Built on [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal acceleration.

## Download

Grab the latest `Yell.dmg` from [Releases](../../releases), open it, and drag Yell to Applications.

**First launch:** macOS blocks the app since it's not notarized.

Go to System Settings → Privacy & Security and click "Open Anyway", or right-click the app and choose Open.

Grant microphone and accessibility access when prompted — microphone for recording, accessibility for typing the result.

## Model Selection 
Bundled with tiny model loaded in memory, but Base model can be downloaded on demand from the menu 
(Improved accuracy, larger resource hit)

## Building from source

Requirements: macOS 14+, Apple Silicon, Xcode Command Line Tools, CMake.

```bash
# Download Whisper models
./download-model.sh

# Build
./build.sh

# Run
open build/Yell.app

# Create a .dmg (optional)
./package.sh
```

## License

MIT

## Contributing

We welcome feedback, issue reports, and PRs!
