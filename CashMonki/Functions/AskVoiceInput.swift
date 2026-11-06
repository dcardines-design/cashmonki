//
//  AskVoiceInput.swift
//  CashMonki
//
//  Live speech-to-text for the Ask composer. Uses on-device recognition when the device
//  supports it, so audio stays on the phone wherever possible.
//

import AVFoundation
import Foundation
import Speech

@MainActor
final class AskVoiceInput: ObservableObject {
    @Published private(set) var isListening = false
    @Published var transcript = ""
    @Published var errorMessage: String?

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        if isListening { stop() } else { Task { await start() } }
    }

    private func start() async {
        guard await Self.hasPermissions() else {
            errorMessage = "Turn on Microphone and Speech Recognition for Cashmonki in Settings to talk to Ask."
            return
        }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            errorMessage = "Voice input isn't available right now."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        // Starting audio blocks on CoreAudio, so it stays off the main thread. A new engine
        // per session means a slow stop of the last one can't collide with this start.
        let engine = AVAudioEngine()
        do {
            try await Self.startAudio(engine, feeding: request)
        } catch {
            errorMessage = "The microphone couldn't start. Try again."
            return
        }

        self.engine = engine
        self.request = request
        transcript = ""
        isListening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let failed = error != nil
            let finished = failed || result?.isFinal == true
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text }
                if failed, self.isListening, self.transcript.isEmpty {
                    self.errorMessage = "Didn't catch that. Try again."
                }
                if finished { self.stop() }
            }
        }
    }

    private nonisolated static func startAudio(_ engine: AVAudioEngine, feeding request: SFSpeechAudioBufferRecognitionRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                    let input = engine.inputNode
                    input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                        request.append(buffer)
                    }
                    engine.prepare()
                    try engine.start()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        guard isListening else { return }
        request?.endAudio()
        cleanUp()
    }

    private func cleanUp() {
        let engine = self.engine
        self.engine = nil
        task?.finish()
        task = nil
        request = nil
        isListening = false
        DispatchQueue.global(qos: .utility).async {
            if let engine {
                if engine.isRunning { engine.stop() }
                engine.inputNode.removeTap(onBus: 0)
            }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func hasPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
