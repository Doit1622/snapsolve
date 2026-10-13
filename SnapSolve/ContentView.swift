import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var coordinator: CaptureCoordinator
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                cameraSection
                statusSection
                intervalPicker
                controls
                answerSection
            }
            .padding()
            .navigationTitle("SnapSolve")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await coordinator.prepareCamera()
                if settings.apiKey.isEmpty { showSettings = true }
            }
        }
    }

    // MARK: - Teilansichten

    private var cameraSection: some View {
        ZStack {
            CameraPreview(session: coordinator.camera.session)
            if let error = coordinator.cameraError {
                Text(error)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .frame(maxHeight: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(coordinator.isRunning ? Color.red : Color.secondary.opacity(0.3), lineWidth: 2)
        }
    }

    private var statusSection: some View {
        HStack(spacing: 8) {
            if case .analyzing = coordinator.status {
                ProgressView()
            } else if case .capturing = coordinator.status {
                ProgressView()
            }
            Text(coordinator.status.label)
                .font(.subheadline)
                .foregroundStyle(statusColor)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        if case .error = coordinator.status { return .red }
        return .secondary
    }

    private var intervalPicker: some View {
        Picker("Intervall", selection: $settings.intervalSeconds) {
            ForEach(AppSettings.intervalOptions, id: \.self) { seconds in
                Text(seconds >= 60 ? "\(seconds / 60) min" : "\(seconds) s").tag(seconds)
            }
        }
        .pickerStyle(.segmented)
        .disabled(coordinator.isRunning)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                if coordinator.isRunning {
                    coordinator.stop()
                } else {
                    coordinator.start(settings: settings)
                }
            } label: {
                Label(coordinator.isRunning ? "Stopp" : "Start",
                      systemImage: coordinator.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(coordinator.isRunning ? .red : .accentColor)
            .disabled(!coordinator.cameraReady)

            Button {
                coordinator.runOnce(settings: settings)
            } label: {
                Label("Einmal", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.isRunning || !coordinator.cameraReady)
        }
        .controlSize(.large)
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Lösung")
                    .font(.headline)
                Spacer()
                Button {
                    coordinator.stopSpeaking()
                } label: {
                    Image(systemName: "speaker.slash")
                }
                Button {
                    coordinator.speakLastAnswer(settings: settings)
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .disabled(coordinator.lastAnswer.isEmpty)
            }

            ScrollView {
                if coordinator.lastAnswer.isEmpty {
                    Text("Noch keine Lösung. Richte die Kamera auf die Aufgabe und tippe auf Start.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(coordinator.lastAnswer)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: .infinity)

            if coordinator.history.count > 1 {
                NavigationLink("Verlauf (\(coordinator.history.count))") {
                    HistoryView()
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var coordinator: CaptureCoordinator

    var body: some View {
        List(coordinator.history) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.text)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Verlauf")
        .toolbar {
            Button("Leeren") { coordinator.clearHistory() }
        }
    }
}
