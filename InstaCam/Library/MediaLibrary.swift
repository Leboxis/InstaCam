import Foundation
import Photos
import UIKit

struct MediaItem: Identifiable {
    let id: String
    let isVideo: Bool
    let thumbnail: UIImage
}

/// Charge les derniers elements de la phototheque pour la galerie.
final class MediaLibrary: ObservableObject {

    @Published var items: [MediaItem] = []
    @Published var authorized = false

    func load(limit: Int = 100) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard status == .authorized || status == .limited else { return }
            DispatchQueue.main.async { self?.authorized = true }
            self?.fetch(limit: limit)
        }
    }

    private func fetch(limit: Int) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        let result = PHAsset.fetchAssets(with: options)
        let manager = PHImageManager.default()
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.isSynchronous = false
        imageOptions.resizeMode = .fast

        var collected: [MediaItem] = []
        let group = DispatchGroup()

        result.enumerateObjects { asset, _, _ in
            group.enter()
            let size = CGSize(width: 300, height: 300)
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill,
                                 options: imageOptions) { image, _ in
                defer { group.leave() }
                guard let image else { return }
                collected.append(MediaItem(id: asset.localIdentifier,
                                           isVideo: asset.mediaType == .video,
                                           thumbnail: image))
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.items = collected
        }
    }
}
