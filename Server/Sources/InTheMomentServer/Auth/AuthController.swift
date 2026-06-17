import Vapor
import Fluent
import JWT
import InTheMomentCore

struct RegisterRequest: Content {
    let email: String
    let password: String
    let displayName: String
    let handle: String
}

struct LoginRequest: Content {
    let email: String
    let password: String
}

struct AuthResponse: Content {
    let token: String
    let creator: Creator
}

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("register", use: register)
        auth.post("login", use: login)

        let protected = auth.grouped(UserToken.authenticator(), UserToken.guardMiddleware())
        protected.get("me", use: me)
    }

    func register(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(RegisterRequest.self)
        let email = body.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard email.contains("@"), email.count >= 3 else {
            throw Abort(.unprocessableEntity, reason: "A valid email is required.")
        }
        guard body.password.count >= 8 else {
            throw Abort(.unprocessableEntity, reason: "Password must be at least 8 characters.")
        }
        guard Creator.isValidHandle(body.handle) else {
            throw Abort(.unprocessableEntity, reason: "Handle must be 3–30 lowercase letters, digits or underscores.")
        }
        guard try await UserModel.query(on: req.db).filter(\.$email == email).first() == nil else {
            throw Abort(.conflict, reason: "An account with that email already exists.")
        }
        guard try await CreatorModel.query(on: req.db).filter(\.$handle == body.handle).first() == nil else {
            throw Abort(.conflict, reason: "That handle is taken.")
        }

        let creator = Creator(displayName: body.displayName, handle: body.handle)
        let creatorModel = CreatorModel(from: creator)
        let hash = try await req.password.async.hash(body.password)
        let user = UserModel(email: email, passwordHash: hash, creatorId: creator.id)

        try await req.db.transaction { db in
            try await creatorModel.create(on: db)
            try await user.create(on: db)
        }

        return try await makeResponse(for: user, creator: creator, req: req)
    }

    func login(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(LoginRequest.self)
        let email = body.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard let user = try await UserModel.query(on: req.db).filter(\.$email == email).first() else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }
        guard try await req.password.async.verify(body.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }
        guard let creatorModel = try await CreatorModel.find(user.creatorId, on: req.db) else {
            throw Abort(.internalServerError, reason: "Creator profile missing.")
        }

        return try await makeResponse(for: user, creator: creatorModel.toDTO(), req: req)
    }

    func me(req: Request) async throws -> Creator {
        let token = try req.auth.require(UserToken.self)
        guard let creatorModel = try await CreatorModel.find(token.creatorId, on: req.db) else {
            throw Abort(.notFound)
        }
        return creatorModel.toDTO()
    }

    private func makeResponse(for user: UserModel, creator: Creator, req: Request) async throws -> AuthResponse {
        let payload = UserToken(userId: try user.requireID(), creatorId: creator.id)
        let token = try await req.jwt.sign(payload)
        return AuthResponse(token: token, creator: creator)
    }
}
