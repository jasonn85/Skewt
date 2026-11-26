import SwiftUI

extension Font {
    static func shareTech(_ textStyle: TextStyle) -> Font {
        let size: CGFloat

        switch textStyle {
        case .largeTitle:
            size = 34
        case .title:
            size = 28
        case .title2:
            size = 22
        case .title3:
            size = 20
        case .headline:
            size = 17
        case .subheadline:
            size = 15
        case .callout:
            size = 16
        case .footnote:
            size = 13
        case .caption:
            size = 12
        case .caption2:
            size = 11
        default:
            size = 17
        }

        return .custom("ShareTechMono-Regular", size: size, relativeTo: textStyle)
    }
}
