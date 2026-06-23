import SwiftUI
import InTheMomentCore

/// The comments thread for an event: a list of comments plus a composer for
/// signed-in users. Loads its own data through ``AppModel`` (views never network).
struct CommentsSection: View {
    let event: Event
    @EnvironmentObject private var model: AppModel

    @State private var comments: [Comment] = []
    @State private var hasLoaded = false
    @State private var draft = ""
    @State private var isPosting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if !hasLoaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if comments.isEmpty {
                Text("No comments yet. Be the first to comment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, canDelete: model.canDelete(comment, in: event)) {
                        await delete(comment)
                    }
                }
            }

            if model.isAccountSignedIn {
                composer
            } else {
                Text("Sign in to join the conversation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: event.id) { await load() }
    }

    private var title: String {
        comments.isEmpty ? "Comments" : "Comments (\(comments.count))"
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Add a comment…", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(isPosting)
            Button {
                Task { await post() }
            } label: {
                if isPosting {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPosting || !Comment.isValidBody(draft))
        }
    }

    private func load() async {
        comments = await model.comments(forEvent: event.id)
        hasLoaded = true
    }

    private func post() async {
        isPosting = true
        defer { isPosting = false }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let created = await model.addComment(eventID: event.id, body: text) else { return }
        comments.append(created)
        draft = ""
    }

    private func delete(_ comment: Comment) async {
        if await model.deleteComment(comment) {
            comments.removeAll { $0.id == comment.id }
        }
    }
}

/// A single comment: author, relative time, body, and an optional delete action.
private struct CommentRow: View {
    let comment: Comment
    let canDelete: Bool
    let onDelete: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(comment.authorName)
                    .font(.subheadline.weight(.semibold))
                Text(comment.createdAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if canDelete {
                    Button(role: .destructive) {
                        Task { await onDelete() }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete comment")
                }
            }
            Text(comment.body)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
