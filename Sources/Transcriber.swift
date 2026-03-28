import Foundation
import CWhisper

class Transcriber {
    private var context: OpaquePointer?

    static let modelKey = "selectedModel"
    static let defaultModel = "ggml-base.en.bin"

    private var modelPath: String {
        let model = UserDefaults.standard.string(forKey: Transcriber.modelKey) ?? Transcriber.defaultModel
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.yell/models/\(model)"
    }

    func reload() -> Bool {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
        return loadModel()
    }

    func loadModel() -> Bool {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("Model not found at \(modelPath)")
            return false
        }

        let cparams = whisper_context_default_params()
        context = whisper_init_from_file_with_params(modelPath, cparams)
        if context == nil {
            print("Failed to initialize whisper context")
            return false
        }
        print("Whisper model loaded successfully")
        return true
    }

    func transcribe(samples: [Float]) -> String {
        guard let ctx = context else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))
        params.no_timestamps = true
        params.single_segment = true
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        let result = "en".withCString { langCStr in
            params.language = langCStr
            return samples.withUnsafeBufferPointer { bufferPointer in
                whisper_full(ctx, params, bufferPointer.baseAddress, Int32(samples.count))
            }
        }

        guard result == 0 else {
            print("Whisper transcription failed with code \(result)")
            return ""
        }

        let segmentCount = whisper_full_n_segments(ctx)
        var text = ""
        for i in 0..<segmentCount {
            if let cStr = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: cStr)
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        if let ctx = context {
            whisper_free(ctx)
        }
    }
}
