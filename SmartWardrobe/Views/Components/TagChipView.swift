import SwiftUI

struct TagChipView: View {
    let name: String
    let color: String

    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: color).opacity(0.2))
            .clipShape(Capsule())
    }
}
