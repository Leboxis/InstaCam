import SwiftUI

struct FilterPickerView: View {

    @Binding var selected: FilterType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(FilterType.allCases) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selected = filter }
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(filter == selected ? Color.yellow : Color.white.opacity(0.15))
                                .frame(width: 58, height: 58)
                                .overlay(
                                    Text(shortLabel(filter))
                                        .font(.caption2).bold()
                                        .foregroundStyle(filter == selected ? .black : .white)
                                )
                            Text(filter.displayName)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func shortLabel(_ filter: FilterType) -> String {
        switch filter {
        case .original: return "A"
        case .vivid: return "V"
        case .warm: return "W"
        case .cool: return "C"
        case .fade: return "F"
        case .mono: return "M"
        case .noir: return "N"
        case .chrome: return "H"
        case .instant: return "I"
        case .clarendon: return "K"
        }
    }
}
