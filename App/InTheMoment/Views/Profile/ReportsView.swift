import SwiftUI
import InTheMomentCore

struct ReportsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var reports: [Report] = []
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if reports.isEmpty {
                ContentUnavailableViewCompat(
                    title: "No reports",
                    systemImage: "checkmark.shield",
                    message: "Submitted reports will appear here."
                )
                .frame(height: 260)
                .listRowSeparator(.hidden)
            } else {
                ForEach(reports) { report in
                    ReportRow(report: report)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Reports")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        reports = await model.moderationReports()
        isLoading = false
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { reports[$0].id }
        reports.remove(atOffsets: offsets)
        Task {
            for id in ids {
                if !(await model.deleteReport(id: id)) {
                    await load()
                    break
                }
            }
        }
    }
}

private struct ReportRow: View {
    let report: Report

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(report.targetType.displayName, systemImage: report.targetType.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(report.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(report.reason.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appAccent)

            if let details = report.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Target: \(report.targetID.uuidString)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

private extension ReportTargetType {
    var displayName: String {
        switch self {
        case .event: "Event"
        case .media: "Media"
        case .comment: "Comment"
        case .creator: "Creator"
        }
    }

    var systemImage: String {
        switch self {
        case .event: "calendar"
        case .media: "photo"
        case .comment: "text.bubble"
        case .creator: "person.crop.circle"
        }
    }
}
