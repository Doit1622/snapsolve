import Foundation
import UIKit
import Combine

/// Steuert die Schleife: Foto → Claude → Vorlesen → warten → von vorn.
@MainActor
final class CaptureCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case capturing
        case analyzing
        case speaking
        case waiting(Int)
        case error(String)

        var label: String {
            switch self {
            case .idle: return "Bereit"
            case .capturing: return "Foto wird aufgenommen …"
            case .analyzing: return "Claude analysiert …"
            case .speaking: return "Wird vorgelesen …"
            case .waiting(let s): return "Nächstes Foto in \(s) s"
            case .error(let msg): return "Fehler: \(msg)"
            }
        }
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let text: String
    }

    @Published private(set) var isRunning = false
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastAnswer = ""
    @Published private(set) var history: [Entry] = []
    @Published private(set) var cameraReady = false
    @Published var cameraError: String?

    let camera = CameraService()
    let speech = SpeechService()

    private var loopTask: Task<Void, Never>?
    private var isProcessing = false

    static let userPrompt = "Löse die Aufgaben auf diesem Foto."

    // MARK: - Kamera

    func prepareCamera() async {
        do {
            try await camera.prepare()
            cameraReady = true
            cameraError = nil
        } catch {
            cameraReady = false
            cameraError = error.localizedDescription
        }
    }

    // MARK: - Schleife

    func start(settings: AppSettings) {
        guard !isRunning, cameraReady else { return }
        isRunning = true
        UIApplication.shared.isIdleTimerDisabled = true

        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let started = Date()
                await self.processOne(settings: settings)
                guard !Task.isCancelled else { break }

                let elapsed = Int(Date().timeIntervalSince(started))
                var remaining = max(0, settings.intervalSeconds - elapsed)
                while remaining > 0 && !Task.isCancelled {
                    self.status = .waiting(remaining)
                    try? await Task.sleep(for: .seconds(1))
                    remaining -= 1
                }
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        speech.stop()
        isRunning = false
        status = .idle
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Einmaliger Durchlauf, z. B. per Button.
    func runOnce(settings: AppSettings) {
        guard !isRunning, !isProcessing, cameraReady else { return }
        Task { await processOne(settings: settings) ; if !isRunning { status = .idle } }
    }

    func speakLastAnswer(settings: AppSettings) {
        guard !lastAnswer.isEmpty else { return }
        Task { await speech.speak(lastAnswer, rate: Float(settings.speechRate)) }
    }

    func stopSpeaking() {
        speech.stop()
    }

    func clearHistory() {
        history.removeAll()
        lastAnswer = ""
    }

    // MARK: - Ein Durchlauf

    private func processOne(settings: AppSettings) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            status = .capturing
            let raw = try await camera.capturePhoto()
            let jpeg = ImagePreparer.prepare(raw)

            status = .analyzing
            let client = ClaudeClient(apiKey: settings.apiKey, model: settings.model)
            let answer = try await client.solve(
                imageJPEG: jpeg,
                systemPrompt: settings.systemPrompt,
                userPrompt: Self.userPrompt
            )
            guard !Task.isCancelled else { return }

            lastAnswer = answer
            history.insert(Entry(date: .now, text: answer), at: 0)
            if history.count > 50 { history.removeLast(history.count - 50) }

            let noTask = answer.lowercased().hasPrefix("keine aufgabe")
            if settings.autoSpeak && !(noTask && settings.skipWhenNoTask) {
                status = .speaking
                await speech.speak(answer, rate: Float(settings.speechRate))
            }
        } catch is CancellationError {
            return
        } catch {
            status = .error(error.localizedDescription)
            // Kurze Pause, damit der Fehler lesbar bleibt und die API nicht gehämmert wird.
            try? await Task.sleep(for: .seconds(3))
        }
    }
}
