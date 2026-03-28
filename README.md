# Yell

Press a hotkey, speak, and your words are typed anywhere — no cloud, no subscription.

Built on [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal acceleration. Runs entirely on-device.

## Download

Grab the latest `Yell.dmg` from [Releases](../../releases), open it, and drag Yell to Applications.

**First launch:** macOS may block the app since it's not notarized. Go to System Settings → Privacy & Security and click "Open Anyway", or right-click the app and choose Open.

Grant microphone and accessibility access when prompted — microphone for recording, accessibility for typing the result.

## Building from source

Requirements: macOS 14+, Apple Silicon, Xcode Command Line Tools, CMake.

```bash
# Download Whisper models
./download-model.sh

# Build
./build.sh

# Run
open build/Yell.app
```

To produce a DMG:

```bash
./package.sh   # outputs dist/Yell.dmg
```

## License

MIT

## Contributing

PRs and issues welcome.
