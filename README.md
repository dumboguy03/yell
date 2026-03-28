# Yell

Press a hotkey, speak, and your words are typed anywhere — no cloud, no subscription.

Built on [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal acceleration. Runs entirely on-device.

## Requirements

- macOS 14+
- Apple Silicon (arm64)
- Xcode Command Line Tools
- CMake

## Install

```bash
# Download the Whisper model (~142MB)
./download-model.sh

# Build
./build.sh

# Run
open build/Yell.app
```

Grant microphone access when prompted.

## License

MIT

## Contributing

PRs and issues welcome.
