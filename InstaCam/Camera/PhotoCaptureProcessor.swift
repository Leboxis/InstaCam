import AVFoundation
import UIKit

/// Delegate de capture photo : convertit les donnees (HEVC/JPEG) en UIImage
/// et transmet a la closure de completion.
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {

    private let completion: (UIImage) -> Void

    init(completion: @escaping (UIImage) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        completion(image)
    }
}
