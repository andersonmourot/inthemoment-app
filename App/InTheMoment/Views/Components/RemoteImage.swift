import SwiftUI
import UIKit

/// Thin wrapper over `AsyncImage` with a consistent placeholder and fill behaviour.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @ViewBuilder
    var body: some View {
        if let url, url.isFileURL {
            if let localURL = MediaStorage.resolvedLocalFileURL(for: url),
               let image = UIImage(contentsOfFile: localURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
            } else {
                placeholder(systemImage: "photo")
                    .clipped()
            }
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .failure:
                    placeholder(systemImage: "photo")
                case .empty:
                    Rectangle()
                        .fill(.quaternary)
                        .shimmering()
                @unknown default:
                    placeholder(systemImage: "photo")
                }
            }
            .clipped()
        }
    }

    private func placeholder(systemImage: String) -> some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
