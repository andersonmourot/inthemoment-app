import SwiftUI
import AVKit
import InTheMomentCore

/// Full-screen viewer for a single photo or video, with a Save-to-device action.
struct MediaDetailView: View {
    let item: MediaItem
    /// Called after the item is successfully saved (used to record a download).
    var onDownloaded: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var downloadState: DownloadState = .idle

    private enum DownloadState: Equatable {
        case idle, downloading, done, failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) { downloadButton }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .photo:
            VStack {
                RemoteImage(url: resolvedURL(item.url), contentMode: .fit)
                if let caption = item.caption {
                    Text(caption).font(.callout).foregroundStyle(.white.opacity(0.8)).padding()
                }
            }
        case .video:
            VideoPlayer(player: AVPlayer(url: resolvedURL(item.url)))
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        switch downloadState {
        case .idle, .failed:
            Button {
                Task { await save() }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!item.isDownloadable)
        case .downloading:
            ProgressView()
        case .done:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private func save() async {
        downloadState = .downloading
        do {
            try await MediaDownloader.saveToPhotoLibrary(item)
            downloadState = .done
            onDownloaded?()
        } catch {
            downloadState = .failed(error.localizedDescription)
        }
    }

    private func resolvedURL(_ url: URL) -> URL {
        MediaStorage.resolvedLocalFileURL(for: url) ?? url
    }
}
