import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT

public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

//    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
//        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
//        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
//        username: Environment.get("DATABASE_USERNAME") ?? "collart_username",
//        password: Environment.get("DATABASE_PASSWORD") ?? "collart_password",
//        database: Environment.get("DATABASE_NAME") ?? "collart_database",
//        tls: .prefer(try .init(configuration: .clientDefault)))
//    ), as: .psql)
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        if app.environment != .development {
            print("Start stage or prodiction")
            tlsConfiguration.certificateVerification = .none
            app.databases.use(.postgres(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
                username: Environment.get("DATABASE_USERNAME") ?? "collart_username",
                password: Environment.get("DATABASE_PASSWORD") ?? "collart_password",
                database: Environment.get("DATABASE_NAME") ?? "collart_database",
                tlsConfiguration: tlsConfiguration
            ), as: .psql)
        } else {
            print("Start development")
            app.databases.use(.postgres(
                hostname: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
                username: Environment.get("DATABASE_USERNAME") ?? "collart_username",
                password: Environment.get("DATABASE_PASSWORD") ?? "collart_password",
                database: Environment.get("DATABASE_NAME") ?? "collart_database"
            ), as: .psql)
        }

    app.migrations.add(CreateUser())
    app.migrations.add(CreateAuthCredential())
    app.migrations.add(CreateAuthProvider())
    app.migrations.add(CreateTab())
    app.migrations.add(CreatePortfolioProject())
    app.migrations.add(CreateMessage())
    app.migrations.add(CreateSkill())
    app.migrations.add(CreateOrder())
    app.migrations.add(CreateUserSkill())
    app.migrations.add(CreateTool())
    app.migrations.add(CreateOrderTool())
    app.migrations.add(CreateInteractions())
    app.migrations.add(CreateOrderParticipant())
    app.migrations.add(CreateUserTool())
    
    app.jwt.signers.use(.hs256(key: Environment.get("JWT_HASH") ?? "SECRET_KEY"))
    app.routes.defaultMaxBodySize = "10mb"
    
    try await app.autoMigrate().get()

    // register routes
    try routes(app)
}
