import SwiftUI
import InTheMomentCore

/// Square thumbnail grid of an event's media.
struct MediaGridView: View {
    let media: [MediaItem]
    var onTap: (MediaItem) -> Void

    private let spacing: CGFloat = 6
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(media) { item in
                Button { onTap(item) } label: {
                    MediaGridCell(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MediaGridCell: View {
    let item: MediaItem

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            RemoteImage(url: item.previewURL)
        }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) {
                if item.kind == .video {
                    Label(item.formattedDuration ?? "", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }
    }
}
