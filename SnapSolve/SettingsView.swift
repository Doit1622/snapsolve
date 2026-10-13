import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API-Key")
                } footer: {
                    Text("Key aus console.anthropic.com. Wird nur im Keychain dieses Geräts gespeichert.")
                }

                Section("Modell") {
                    Picker("Modell", selection: $settings.model) {
                        ForEach(AppSettings.availableModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Sprachausgabe") {
                    Toggle("Lösung automatisch vorlesen", isOn: $settings.autoSpeak)
                    Toggle("Bei „Keine Aufgabe erkennbar“ still bleiben", isOn: $settings.skipWhenNoTask)
                    VStack(alignment: .leading) {
                        Text("Sprechtempo: \(Int(settings.speechRate * 100)) %")
                        Slider(value: $settings.speechRate, in: 0.3...0.7, step: 0.05)
                    }
                }

                Section {
                    TextEditor(text: $settings.systemPrompt)
                        .frame(minHeight: 220)
                        .font(.footnote)
                    Button("Standard-Anweisung wiederherstellen") {
                        settings.resetPrompt()
                    }
                } header: {
                    Text("Anweisung an Claude")
                } footer: {
                    Text("Hier kannst du festlegen, wie Claude die Aufgaben lösen und formulieren soll.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
