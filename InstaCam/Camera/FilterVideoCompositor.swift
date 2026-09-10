import AVFoundation
import CoreImage
import UIKit

/// Configuration partagee car AVFoundation instancie lui-meme le compositor
/// (via `customVideoCompositorClass`) sans pouvoir passer d'arguments.
final class FilterVideoConfig {
    static let shared = FilterVideoConfig()
    var filter: FilterType = .original
    private init() {}
}

/// Applique `FilterEngine` a chaque frame lors d'un export video.
/// Chaque frame est traitee en GPU via Core Image puis reinjectee.
final class FilterVideoCompositor: NSObject, AVVideoCompositing {

    let sourcePixelBufferAttributes: [String: Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: [Int(kCVPixelFormatType_32BGRA)]
    ]

    let requiredPixelBufferAttributesForRenderContext: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]

    private let context = CIContext()
    private let renderQueue = DispatchQueue(label: "com.example.InstaCam.videoCompositor")
    private var renderContext: AVVideoCompositionRenderContext?

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderQueue.sync { renderContext = newRenderContext }
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [weak self] in
            guard let self else { return }
            let trackID = request.sourceTrackIDs.first?.int32Value ?? 0
            guard let source = request.sourceFrame(byTrackID: trackID) else {
                request.finish(with: NSError(domain: "FilterVideoCompositor", code: -1))
                return
            }
            let input = CIImage(cvPixelBuffer: source)
            let output = FilterEngine.shared.apply(FilterVideoConfig.shared.filter, to: input)
            guard let destination = request.renderContext.newPixelBuffer() else {
                request.finish(with: NSError(domain: "FilterVideoCompositor", code: -2))
                return
            }
            self.context.render(output, to: destination)
            request.finish(withComposedVideoFrame: destination)
        }
    }
}

final class FilterCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    var timeRange: CMTimeRange = .zero
    var enablePostProcessing = false
    var containsTweening = false
    var requiredSourceTrackIDs: [NSValue]? = nil
    var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
}
