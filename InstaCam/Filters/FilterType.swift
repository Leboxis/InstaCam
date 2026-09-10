import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

enum FilterType: String, CaseIterable, Identifiable {
    case original
    case vivid
    case warm
    case cool
    case fade
    case mono
    case noir
    case chrome
    case instant
    case clarendon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .vivid: return "Vivid"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .fade: return "Fade"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .chrome: return "Chrome"
        case .instant: return "Instant"
        case .clarendon: return "Clarendon"
        }
    }
}
