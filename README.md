# SnapSolve

Private iOS-App (SwiftUI, iOS 17+): fotografiert in einstellbaren Abständen, schickt das Bild an Claude, lässt die Aufgaben auf dem Bild lösen und liest die Lösung per Sprachausgabe vor.

## Wichtig: Abo-Token geht nicht, API-Key nötig

Das Claude-Abo (Pro/Max) kann nicht aus eigenen Apps heraus verwendet werden. Die Nutzungsbedingungen erlauben den Abo-Login nur in Anthropics eigenen Clients, und der Abo-Token wird für die Messages API nicht akzeptiert. Die App nutzt deshalb einen normalen API-Key:

1. Auf https://console.anthropic.com anmelden (derselbe Account geht).
2. Guthaben aufladen (Pay-as-you-go, unabhängig vom Abo).
3. Unter *API Keys* einen Key erzeugen (`sk-ant-…`) und in der App unter Einstellungen eintragen.

Grobe Kosten pro Foto (1568 px lange Kante, kurze Antwort):

| Modell | ca. pro Foto |
|---|---|
| Claude Opus 5.5 (Standard) | 2–4 Cent |
| Claude Sonnet 5.5 | 1–2 Cent |
| Claude Haiku 5.5 | unter 0,5 Cent |

Bei 30 s Intervall sind das mit Opus etwa 3–5 Euro pro Stunde Dauerbetrieb.

## Build

Du brauchst einen Mac mit Xcode 15 oder neuer. Zwei Wege:

### A) Mit XcodeGen (empfohlen)

```bash
brew install xcodegen
cd SnapSolve
xcodegen generate
open SnapSolve.xcodeproj
```

### B) Manuell in Xcode

1. Xcode → *File → New → Project → iOS → App*, Name `SnapSolve`, Interface SwiftUI, Language Swift.
2. Die automatisch erzeugten Dateien `SnapSolveApp.swift` und `ContentView.swift` löschen.
3. Alle Dateien aus dem Ordner `SnapSolve/` dieses Repos per Drag & Drop ins Projekt ziehen (*Copy items if needed* anhaken).
4. Im Target unter *Info* den Eintrag `Privacy - Camera Usage Description` hinzufügen, z. B. „SnapSolve fotografiert Aufgaben für Claude.“
5. Unter *Signing & Capabilities* dein Apple-Team wählen (eine kostenlose Apple-ID reicht, die App läuft dann 7 Tage und muss danach neu installiert werden).

Dann iPhone anschließen, als Ziel wählen, ▶ drücken. Beim ersten Start auf dem iPhone unter *Einstellungen → Allgemein → VPN & Geräteverwaltung* dem Entwicklerprofil vertrauen.

Der iOS-Simulator hat keine Kamera, daher nur auf einem echten Gerät testen.

## Bedienung

- **Intervall** (5 s bis 2 min) über die Segmentleiste wählen.
- **Start** beginnt die Schleife: Foto → Claude → vorlesen → warten → von vorn. Der Bildschirm bleibt dabei an.
- **Einmal** macht einen einzelnen Durchlauf.
- Lautsprecher-Symbol liest die letzte Lösung erneut vor, das durchgestrichene Symbol bricht die Sprachausgabe ab.
- **Verlauf** zeigt die letzten 50 Lösungen.
- Zahnrad: API-Key, Modell, Sprachausgabe (Tempo, automatisches Vorlesen, bei „Keine Aufgabe erkennbar“ still bleiben) und die Anweisung an Claude.

Die Sprachausgabe funktioniert auch bei aktiviertem Stummschalter und über Bluetooth-Kopfhörer.

## Einschränkungen

- iOS stoppt die Kamera, sobald die App in den Hintergrund geht. Die Schleife wird dann automatisch beendet. Die App muss im Vordergrund bleiben.
- Läuft eine Anfrage länger als das Intervall, folgt das nächste Foto direkt danach. Anfragen überlappen sich nie.
- Die Bilder werden mit maximal 1568 px langer Kante als JPEG gesendet und nicht auf dem Gerät gespeichert.

## Technik

| Datei | Zweck |
|---|---|
| `SnapSolveApp.swift` | App-Einstieg, stoppt die Schleife beim Wechsel in den Hintergrund |
| `AppSettings.swift` | Einstellungen (UserDefaults), Standard-Prompt, Modellliste |
| `KeychainStore.swift` | API-Key im Keychain |
| `CameraService.swift` | AVCaptureSession, Fotoaufnahme, Bildverkleinerung |
| `CameraPreview.swift` | Live-Vorschau für SwiftUI |
| `ClaudeClient.swift` | Aufruf der Messages API mit Bild als Base64, inkl. Server-Fallback bei Ablehnungen |
| `SpeechService.swift` | AVSpeechSynthesizer, wartet bis die Ausgabe fertig ist |
| `CaptureCoordinator.swift` | Die Schleife, Status, Verlauf |
| `ContentView.swift`, `SettingsView.swift` | Oberfläche |

## Web-Version (ohne Mac)

Im Ordner `docs/` liegt dieselbe App als einzelne HTML-Seite für Safari auf dem iPhone. Sie braucht kein Xcode, nur HTTPS-Hosting, z. B. GitHub Pages mit dem Ordner `/docs`. Anleitung in `docs/README.md`.
