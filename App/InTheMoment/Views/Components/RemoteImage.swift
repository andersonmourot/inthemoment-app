import SwiftUI

/// Thin wrapper over `AsyncImage` with a consistent placeholder and fill behaviour.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(systemImage: "photo")
            case .empty:
                ZStack {
                    placeholder(systemImage: "photo")
                    ProgressView()
                }
            @unknown default:
                placeholder(systemImage: "photo")
            }
        }
        .clipped()
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
