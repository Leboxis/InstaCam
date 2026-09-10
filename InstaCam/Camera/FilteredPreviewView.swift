import SwiftUI
import AVFoundation
import MetalKit
import Combine

/// Vue d'apercu temps reel : recoit les frames CIImage et les affiche via
/// un `MTKView` + `CIContext(mtlDevice:)`. Même pipeline GPU que la capture.
struct FilteredPreviewView: UIViewRepresentable {

    @ObservedObject var camera: CameraController

    func makeCoordinator() -> Coordinator { Coordinator(camera: camera) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.delegate = context.coordinator

        camera.frameStream
            .receive(on: DispatchQueue.main)
            .sink { [weak view] image in
                context.coordinator.latestImage = image
                view?.setNeedsDisplay()
            }
            .store(in: &context.coordinator.cancellables)

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.filter = camera.currentFilter
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var cancellables = Set<AnyCancellable>()
        var latestImage: CIImage?
        var filter: FilterType = .original

        private let commandQueue: MTLCommandQueue?
        private let ciContext: CIContext

        init(camera: CameraController) {
            if let device = MTLCreateSystemDefaultDevice() {
                commandQueue = device.makeCommandQueue()
                ciContext = CIContext(mtlDevice: device)
            } else {
                commandQueue = nil
                ciContext = CIContext()
            }
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let image = latestImage,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

            let filtered = FilterEngine.shared.apply(filter, to: image)
            let bounds = CGRect(origin: .zero, size: view.drawableSize)
            ciContext.render(filtered,
                             to: drawable.texture,
                             commandBuffer: commandBuffer,
                             bounds: bounds,
                             colorSpace: CGColorSpaceCreateDeviceRGB())
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
