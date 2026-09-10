import XCTest
import CoreImage
@testable import InstaCam

final class FilterEngineTests: XCTestCase {

    private let engine = FilterEngine()

    private func solidImage() -> CIImage {
        CIImage(color: .init(red: 0.5, green: 0.4, blue: 0.3, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
    }

    func testAllFiltersProduceOutput() {
        for filter in FilterType.allCases {
            let output = engine.apply(filter, to: solidImage())
            XCTAssertFalse(output.extent.isEmpty, "\(filter) ne doit pas produire une image vide")
        }
    }

    func testMonoRemovesSaturation() {
        let output = engine.apply(.mono, to: solidImage())
        XCTAssertNotNil(engine.render(output))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(output,
                       toBitmap: &pixel,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: colorSpace)
        XCTAssertEqual(pixel[0], pixel[1], accuracy: 6, "Mono doit egaliser R et G")
        XCTAssertEqual(pixel[1], pixel[2], accuracy: 6, "Mono doit egaliser G et B")
    }

    func testLUTCubeDataSize() {
        let dimension = 16
        let data = FilterEngine.instagramCubeData(dimension: dimension)
        XCTAssertEqual(data.count, dimension * dimension * dimension * 4 * MemoryLayout<Float>.size)
    }

    func testJPEGRendering() {
        let output = engine.apply(.clarendon, to: solidImage())
        let data = engine.render(output, toJPEG: 0.9)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }
}
