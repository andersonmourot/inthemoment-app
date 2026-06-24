import Foundation

public enum ReportTargetType: String, Codable, Sendable, CaseIterable {
    case event
    case media
    case comment
    case creator
}

public enum ReportReason: String, Codable, Sendable, CaseIterable {
    case spam
    case harassment
    case inappropriate
    case copyright
    case other

    public var displayName: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment"
        case .inappropriate: "Inappropriate content"
        case .copyright: "Copyright concern"
        case .other: "Other"
        }
    }
}

public struct ReportRequest: Codable, Sendable, Equatable {
    public let targetType: ReportTargetType
    public let targetID: UUID
    public let eventID: UUID?
    public let reason: ReportReason
    public let details: String?

    public init(
        targetType: ReportTargetType,
        targetID: UUID,
        eventID: UUID? = nil,
        reason: ReportReason,
        details: String? = nil
    ) {
        self.targetType = targetType
        self.targetID = targetID
        self.eventID = eventID
        self.reason = reason
        self.details = details
    }
}
