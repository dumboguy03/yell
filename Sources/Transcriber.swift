import Foundation
import CWhisper

class Transcriber {
    private let queue = DispatchQueue(label: "com.yell.transcriber", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<UInt8>()
    private var context: OpaquePointer?

    static let modelKey = "selectedModel"
    static let defaultModel = "ggml-tiny.en.bin"

    init() {
        queue.setSpecific(key: queueKey, value: 1)
    }

    private var modelPath: String {
        let model = UserDefaults.standard.string(forKey: Transcriber.modelKey) ?? Transcriber.defaultModel
        // Prefer bundled model, fall back to ~/.yell/models/
        if let bundled = Bundle.main.path(forResource: model, ofType: nil) {
            return bundled
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.yell/models/\(model)"
    }

    private static func createContext(modelPath: String) -> OpaquePointer? {
        let cparams = whisper_context_default_params()
        return whisper_init_from_file_with_params(modelPath, cparams)
    }

    static func canLoadModel(atPath path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path),
              let ctx = createContext(modelPath: path) else {
            return false
        }
        whisper_free(ctx)
        return true
    }

    func loadModel() -> Bool {
        queue.sync {
            loadModelLocked()
        }
    }

    func reload(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let success = self.reloadLocked()
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func transcribe(samples: [Float], completion: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let text = self.transcribeLocked(samples: samples)
            DispatchQueue.main.async {
                completion(text)
            }
        }
    }

    private func reloadLocked() -> Bool {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
        return loadModelLocked()
    }

    private func loadModelLocked() -> Bool {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("Model not found at \(modelPath)")
            return false
        }

        context = Transcriber.createContext(modelPath: modelPath)
        if context == nil {
            print("Failed to initialize whisper context")
            return false
        }
        print("[Yell] Loaded model: \(modelPath)")
        return true
    }

    private func transcribeLocked(samples: [Float]) -> String {
        guard let ctx = context else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))
        params.no_timestamps = true
        params.single_segment = true
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        // whisper_full must run inside this closure because params.language
        // points into a Swift-managed C string buffer.
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
        let freeContext = { [self] in
            if let ctx = self.context {
                whisper_free(ctx)
            }
        }

        if DispatchQueue.getSpecific(key: queueKey) != nil {
            freeContext()
        } else {
            queue.sync(execute: freeContext)
        }
    }
}
