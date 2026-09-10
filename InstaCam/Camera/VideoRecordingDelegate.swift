import AVFoundation

/// Delegate d'enregistrement video : rend l'URL du fichier une fois ecrit.
final class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {

    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        completion(error == nil ? outputFileURL : nil)
    }
}
