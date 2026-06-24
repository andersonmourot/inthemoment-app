import SwiftUI
import InTheMomentCore

/// Square thumbnail grid of an event's media.
struct MediaGridView: View {
    let media: [MediaItem]
    var onTap: (MediaItem) -> Void
    var onDelete: ((MediaItem) -> Void)? = nil

    private let spacing: CGFloat = 6
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(media) { item in
                Button { onTap(item) } label: {
                    MediaGridCell(item: item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Remove Media", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

private struct MediaGridCell: View {
    let item: MediaItem

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RemoteImage(url: item.previewURL)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomLeading) {
                videoBadge
            }
    }

    @ViewBuilder
    private var videoBadge: some View {
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
