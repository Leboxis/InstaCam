import Foundation
import Photos
import UIKit

/// Sauvegarde photos et videos dans la phototheque.
enum PhotoSaver {

    static func savePhoto(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(PhotoSaverError.denied))
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success { completion(.success(())) }
                    else { completion(.failure(error ?? PhotoSaverError.failed)) }
                }
            }
        }
    }

    static func saveVideo(at url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(PhotoSaverError.denied))
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success { completion(.success(())) }
                    else { completion(.failure(error ?? PhotoSaverError.failed)) }
                }
            }
        }
    }
}

enum PhotoSaverError: LocalizedError {
    case denied
    case failed

    var errorDescription: String? {
        switch self {
        case .denied: return "Acces a la phototheque refuse."
        case .failed: return "Enregistrement impossible."
        }
    }
}
