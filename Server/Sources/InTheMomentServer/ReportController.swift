import Vapor
import Fluent
import InTheMomentCore

struct ReportController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserToken.authenticator(), UserToken.guardMiddleware())
        protected.post("reports", use: create)
    }

    func create(req: Request) async throws -> HTTPStatus {
        let token = try req.auth.require(UserToken.self)
        let userId = try token.requireUserID()
        let body = try req.content.decode(ReportRequest.self)
        let details = body.details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = ReportRequest(
            targetType: body.targetType,
            targetID: body.targetID,
            eventID: body.eventID,
            reason: body.reason,
            details: details?.isEmpty == true ? nil : details
        )
        try await ReportModel(userId: userId, request: request).create(on: req.db)
        return .created
    }
}
