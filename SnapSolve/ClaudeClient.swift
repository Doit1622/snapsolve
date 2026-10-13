import Foundation

/// Schlanker Client für die Claude Messages API (POST /v1/messages) ohne SDK.
struct ClaudeClient {
    let apiKey: String
    let model: String

    enum ClientError: LocalizedError {
        case missingKey
        case http(Int, String)
        case refusal(String)
        case emptyAnswer
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingKey: return "Kein API-Key hinterlegt. Bitte in den Einstellungen eintragen."
            case .http(let code, let message): return "API-Fehler \(code): \(message)"
            case .refusal(let reason): return "Claude hat die Anfrage abgelehnt. \(reason)"
            case .emptyAnswer: return "Claude hat keinen Text zurückgegeben."
            case .badResponse: return "Unerwartete Antwort vom Server."
            }
        }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func solve(imageJPEG: Data, systemPrompt: String, userPrompt: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.missingKey
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 8000,
            "system": systemPrompt,
            "output_config": ["effort": "high"],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageJPEG.base64EncodedString(),
                            ],
                        ],
                        ["type": "text", "text": userPrompt],
                    ],
                ],
            ],
        ]

        // Server-seitiger Fallback bei Sicherheitsablehnungen (Opus/Sonnet 5.5). Haiku unterstützt das nicht.
        if model.hasPrefix("claude-opus") || model.hasPrefix("claude-sonnet") {
            body["fallbacks"] = "default"
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200..<300).contains(http.statusCode) else {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String)
                ?? String(data: data, encoding: .utf8)
                ?? "Unbekannter Fehler"
            throw ClientError.http(http.statusCode, message)
        }

        guard let json else { throw ClientError.badResponse }

        if json["stop_reason"] as? String == "refusal" {
            let details = json["stop_details"] as? [String: Any]
            let explanation = details?["explanation"] as? String ?? ""
            throw ClientError.refusal(explanation)
        }

        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw ClientError.emptyAnswer }
        return text
    }
}
