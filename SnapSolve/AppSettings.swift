import Foundation
import Combine

/// Alle Einstellungen. API-Key liegt im Keychain, der Rest in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let defaultSystemPrompt = """
    Du bist ein Assistent, der Aufgaben auf Fotos löst. Auf dem Bild sind Aufgaben zu sehen, zum Beispiel Rechenaufgaben, Textaufgaben, Multiple-Choice-Fragen oder Verständnisfragen. Löse jede erkennbare Aufgabe vollständig und korrekt.

    Deine Antwort wird per Sprachausgabe vorgelesen. Deshalb:
    - Antworte auf Deutsch in kurzen, klaren Sätzen.
    - Kein Markdown, keine Aufzählungszeichen, keine Tabellen, kein LaTeX.
    - Schreibe Formeln und Ergebnisse so, dass sie vorgelesen gut verständlich sind.
    - Nenne pro Aufgabe zuerst das Ergebnis, danach in höchstens zwei Sätzen den Lösungsweg.
    - Bei Multiple Choice nenne den Buchstaben und den Text der richtigen Antwort.

    Wenn auf dem Bild keine Aufgabe erkennbar ist oder das Bild zu unscharf ist, antworte ausschließlich mit: Keine Aufgabe erkennbar.
    """

    static let availableModels: [(id: String, name: String)] = [
        ("claude-opus-5-5", "Claude Opus 5.5 (beste Qualität)"),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5 (schneller, günstiger)"),
        ("claude-haiku-5-5", "Claude Haiku 5.5 (sehr günstig)"),
    ]

    static let intervalOptions = [5, 10, 20, 30, 60, 120]

    @Published var apiKey: String {
        didSet { KeychainStore.save(apiKey, for: Keys.apiKey) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    @Published var intervalSeconds: Int {
        didSet { defaults.set(intervalSeconds, forKey: Keys.interval) }
    }
    @Published var autoSpeak: Bool {
        didSet { defaults.set(autoSpeak, forKey: Keys.autoSpeak) }
    }
    @Published var skipWhenNoTask: Bool {
        didSet { defaults.set(skipWhenNoTask, forKey: Keys.skipWhenNoTask) }
    }
    @Published var speechRate: Double {
        didSet { defaults.set(speechRate, forKey: Keys.speechRate) }
    }
    @Published var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let apiKey = "anthropic-api-key"
        static let model = "model"
        static let interval = "intervalSeconds"
        static let autoSpeak = "autoSpeak"
        static let skipWhenNoTask = "skipWhenNoTask"
        static let speechRate = "speechRate"
        static let systemPrompt = "systemPrompt"
    }

    init() {
        apiKey = KeychainStore.load(for: Keys.apiKey) ?? ""
        model = defaults.string(forKey: Keys.model) ?? "claude-opus-5-5"
        let storedInterval = defaults.integer(forKey: Keys.interval)
        intervalSeconds = storedInterval > 0 ? storedInterval : 30
        autoSpeak = defaults.object(forKey: Keys.autoSpeak) as? Bool ?? true
        skipWhenNoTask = defaults.object(forKey: Keys.skipWhenNoTask) as? Bool ?? true
        speechRate = defaults.object(forKey: Keys.speechRate) as? Double ?? 0.5
        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
    }

    func resetPrompt() {
        systemPrompt = Self.defaultSystemPrompt
    }
}
