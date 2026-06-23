import SwiftUI
import InTheMomentCore

/// Square thumbnail grid of an event's media.
struct MediaGridView: View {
    let media: [MediaItem]
    var onTap: (MediaItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 6)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(media) { item in
                Button { onTap(item) } label: {
                    GeometryReader { proxy in
                        RemoteImage(url: item.previewURL)
                            .frame(width: proxy.size.width, height: proxy.size.width)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
