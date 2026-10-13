import AVFoundation
import UIKit

/// Kapselt AVCaptureSession und liefert auf Anfrage ein JPEG.
final class CameraService: NSObject {
    enum CameraError: LocalizedError {
        case notAuthorized, noDevice, notRunning, busy, captureFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Kein Kamerazugriff. Bitte in den iOS-Einstellungen erlauben."
            case .noDevice: return "Keine Rückkamera gefunden."
            case .notRunning: return "Kamera läuft nicht."
            case .busy: return "Kamera ist gerade beschäftigt."
            case .captureFailed: return "Foto konnte nicht aufgenommen werden."
            }
        }
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "de.frederik.SnapSolve.camera")
    private var captureContinuation: CheckedContinuation<Data, Error>?
    private var isConfigured = false

    // MARK: - Setup

    func prepare() async throws {
        guard await requestAccess() else { throw CameraError.notAuthorized }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configureSessionIfNeeded()
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw CameraError.noDevice
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced

        // Autofokus auf Nahbereich (Papier, Bildschirm) optimieren, falls unterstützt.
        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.unlockForConfiguration()
        }
        isConfigured = true
    }

    func start() {
        queue.async {
            if self.isConfigured && !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    // MARK: - Aufnahme

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard self.captureContinuation == nil else {
                    continuation.resume(throwing: CameraError.busy)
                    return
                }
                guard self.session.isRunning else {
                    continuation.resume(throwing: CameraError.notRunning)
                    return
                }
                self.captureContinuation = continuation

                let settings: AVCapturePhotoSettings
                if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                settings.photoQualityPrioritization = .balanced
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        queue.async {
            let continuation = self.captureContinuation
            self.captureContinuation = nil
            if let error {
                continuation?.resume(throwing: error)
                return
            }
            guard let data = photo.fileDataRepresentation() else {
                continuation?.resume(throwing: CameraError.captureFailed)
                return
            }
            continuation?.resume(returning: data)
        }
    }
}

/// Verkleinert das Foto auf die für Claude sinnvolle Größe (max. 1568 px lange Kante)
/// und bäckt die Ausrichtung ein. Spart Tokens und Übertragungszeit.
enum ImagePreparer {
    static func prepare(_ data: Data, maxDimension: CGFloat = 1568, quality: CGFloat = 0.8) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality) ?? data
    }
}
