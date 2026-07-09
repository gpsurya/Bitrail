import SwiftUI

struct GlassCard<Content: View>: View {
    var accent: Color = .secondary
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent.opacity(0.8))
                .frame(width: 3)
                .padding(.vertical, 10)

            content
                .padding(.vertical, 12)
                .padding(.trailing, 12)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.08), radius: 4, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accent.opacity(scheme == .dark ? 0.25 : 0.18), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SectionLabel: View {
    let title: String
    let symbol: String
    var accent: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
            Text(title.uppercased())
                .font(Theme.mono(10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(accent)
        }
    }
}
