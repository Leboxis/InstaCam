import AVFoundation
import CoreImage
import Combine
import UIKit

enum CaptureMode {
    case photo
    case video
}

enum CameraError: LocalizedError {
    case denied
    case noDevice
    case configurationFailed
    case notReady

    var errorDescription: String? {
        switch self {
        case .denied: return "Acces camera refuse. Activez-le dans Reglages."
        case .noDevice: return "Aucune camera disponible."
        case .configurationFailed: return "Configuration de la session impossible."
        case .notReady: return "La session camera n'est pas prete."
        }
    }
}

/// Controleur central : configure `AVCaptureSession`, gere photo et video,
/// expose le flux video brut pour l'apercu filtre.
final class CameraController: NSObject, ObservableObject {

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.example.InstaCam.session")
    private let videoOutputQueue = DispatchQueue(label: "com.example.InstaCam.videoOutput")

    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    @Published var isReady = false
    @Published var isRecording = false
    @Published var currentFilter: FilterType = .original
    @Published var errorMessage: String?
    @Published var capturedImage: UIImage?

    /// Derniere frame brute (non filtree), envoyee aux vues d'apercu.
    let frameStream = PassthroughSubject<CIImage, Never>()

    private var photoProcessors: [Int64: PhotoCaptureProcessor] = [:]
    private var recordingDelegate: VideoRecordingDelegate?

    // MARK: - Lifecycle

    func start() {
        sessionQueue.async { [weak self] in
            self?.configureIfNeeded()
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isReady = true }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isReady = false }
        }
    }

    // MARK: - Configuration

    private func configureIfNeeded() {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = Self.bestBackCamera() else {
            report(.noDevice)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.configurationFailed }
            session.addInput(input)
            videoDeviceInput = input
        } catch {
            report(error)
            return
        }

        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        guard session.canAddOutput(photoOutput) else {
            report(CameraError.configurationFailed)
            return
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        photoOutput.isHighResolutionCaptureEnabled = true

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.movieFragmentInterval = .invalid
        }

        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        configureDevice(device)
    }

    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = true
            }
            device.unlockForConfiguration()
        } catch {
            report(error)
        }
    }

    private static func bestBackCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first
    }

    // MARK: - Photo

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings(
                format: [AVVideoCodecKey: AVVideoCodecType.hevc]
            )
            settings.photoQualityPrioritization = .quality
            if self.photoOutput.isHighResolutionCaptureEnabled {
                settings.isHighResolutionPhotoEnabled = true
            }
            let processor = PhotoCaptureProcessor { [weak self] image in
                guard let self else { return }
                let filtered = self.filtered(image)
                DispatchQueue.main.async { self.capturedImage = filtered }
            }
            self.photoProcessors[settings.uniqueID] = processor
            self.photoOutput.capturePhoto(with: settings, delegate: processor)
        }
    }

    // MARK: - Video

    func toggleRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            } else {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("instacam-\(UUID().uuidString).mov")
                let delegate = VideoRecordingDelegate { [weak self] outputURL in
                    guard let self, let outputURL else { return }
                    let merged = self.mergeFilterIntoVideo(at: outputURL)
                    DispatchQueue.main.async {
                        self.isRecording = false
                        self.exportedVideoURL = merged ?? outputURL
                    }
                }
                self.recordingDelegate = delegate
                if let connection = self.movieOutput.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                self.movieOutput.startRecording(to: url, recordingDelegate: delegate)
                DispatchQueue.main.async { self.isRecording = true }
            }
        }
    }

    @Published var exportedVideoURL: URL?

    /// Re-encode la video capturee en appliquant le filtre courant frame par frame.
    private func mergeFilterIntoVideo(at url: URL) -> URL? {
        guard currentFilter != .original else { return url }
        FilterVideoConfig.shared.filter = currentFilter
        let asset = AVAsset(url: url)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return url
        }
        export.videoComposition = Self.makeComposition(for: asset)
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("instacam-filtered-\(UUID().uuidString).mov")
        export.outputURL = out
        export.outputFileType = .mov

        let semaphore = DispatchSemaphore(value: 0)
        export.exportAsynchronously { semaphore.signal() }
        semaphore.wait()
        return export.status == .completed ? out : url
    }

    private static func makeComposition(for asset: AVAsset) -> AVMutableVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = FilterVideoCompositor.self
        composition.frameDuration = CMTime(value: 1, timescale: 30)

        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize.applying(track.preferredTransform)
            composition.renderSize = CGSize(width: abs(size.width), height: abs(size.height))
        }

        let instruction = FilterCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        composition.instructions = [instruction]
        return composition
    }

    // MARK: - Filtering

    private func filtered(_ image: UIImage) -> UIImage {
        guard currentFilter != .original, let ci = CIImage(image: image) else { return image }
        let out = FilterEngine.shared.apply(currentFilter, to: ci)
        return FilterEngine.shared.renderToUIImage(out, orientation: image.imageOrientation) ?? image
    }

    // MARK: - Helpers

    private func report(_ error: Error) {
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }
}

// MARK: - Video data output (apercu temps reel)

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        frameStream.send(image)
    }
}
