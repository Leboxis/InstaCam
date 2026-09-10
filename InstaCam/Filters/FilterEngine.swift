import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Applique un rendu type Instagram (colorimetrie + courbes + LUT 3D)
/// sur une image Core Image. Le pipeline est identique a celui utilise
/// pour l'apercu temps reel et pour la capture finale.
final class FilterEngine {

    static let shared = FilterEngine()

    private let context: CIContext
    private var lutCache: [FilterType: CIColorCube] = [:]

    init() {
        context = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])
    }

    // MARK: - Public

    func apply(_ type: FilterType, to image: CIImage) -> CIImage {
        switch type {
        case .original:
            return image
        case .vivid:
            return image.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.35,
                kCIInputContrastKey: 1.08,
                kCIInputBrightnessKey: 0.02
            ])
        case .warm:
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 5200, y: 0)
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.15])
        case .cool:
            return image
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0),
                    "inputTargetNeutral": CIVector(x: 7800, y: 0)
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.1])
        case .fade:
            return image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.8,
                    kCIInputContrastKey: 0.9,
                    kCIInputBrightnessKey: 0.05
                ])
                .applyingFilter("CIVignette", parameters: [
                    kCIInputIntensityKey: 0.6,
                    kCIInputRadiusKey: 1.5
                ])
        case .mono:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        case .noir:
            return image.applyingFilter("CIPhotoEffectNoir")
        case .chrome:
            return image.applyingFilter("CIPhotoEffectChrome")
        case .instant:
            return image.applyingFilter("CIPhotoEffectInstant")
        case .clarendon:
            return image
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 1.5,
                    kCIInputContrastKey: 1.2,
                    kCIInputBrightnessKey: -0.02
                ])
                .applyingFilter("CIColorCube", parameters: [
                    "inputCubeDimension": 32,
                    "inputCubeData": Self.instagramCubeData(dimension: 32)
                ])
        }
    }

    func render(_ image: CIImage, toJPEG quality: CGFloat = 0.92) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality
        ])
    }

    func render(_ image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }

    func renderToUIImage(_ image: CIImage, orientation: UIImage.Orientation = .up) -> UIImage? {
        guard let cg = render(image) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: orientation)
    }

    // MARK: - LUT 3D "teal & orange" (look Instagram)

    private static var cubeCache: [Int: Data] = [:]

    /// Genere une LUT 3D programmatique : ombres froides, hautes lumieres
    /// chaudes, courbe en S leger. C'est ce genre de colorimetrie qui donne
    /// la "signature" visuelle d'Instagram.
    static func instagramCubeData(dimension: Int) -> Data {
        if let cached = cubeCache[dimension] { return cached }
        let size = dimension
        let floatCount = size * size * size * 4
        var cube = [Float](repeating: 0, count: floatCount)
        var offset = 0
        for b in 0..<size {
            let blue = Float(b) / Float(size - 1)
            for g in 0..<size {
                let green = Float(g) / Float(size - 1)
                for r in 0..<size {
                    let red = Float(r) / Float(size - 1)
                    var (outR, outG, outB) = (red, green, blue)

                    // Courbe en S : contraste doux
                    outR = sCurve(outR)
                    outG = sCurve(outG)
                    outB = sCurve(outB)

                    let luma = 0.2126 * outR + 0.7152 * outG + 0.0722 * outB
                    let shadowWeight = max(0, 1 - luma * 2)
                    let highlightWeight = max(0, (luma - 0.5) * 2)

                    // Ombres -> teal, hautes lumieres -> orange
                    outR += highlightWeight * 0.08 - shadowWeight * 0.04
                    outG += highlightWeight * 0.02
                    outB += shadowWeight * 0.09 - highlightWeight * 0.03

                    outR = min(max(outR, 0), 1)
                    outG = min(max(outG, 0), 1)
                    outB = min(max(outB, 0), 1)

                    cube[offset + 0] = outR
                    cube[offset + 1] = outG
                    cube[offset + 2] = outB
                    cube[offset + 3] = 1
                    offset += 4
                }
            }
        }
        let data = cube.withUnsafeBufferPointer { Data(buffer: $0) }
        cubeCache[dimension] = data
        return data
    }

    private static func sCurve(_ x: Float) -> Float {
        // approximation douce d'une courbe en S
        x * x * (3 - 2 * x)
    }
}
