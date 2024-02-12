import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "It works!"
    }
    
    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    try app.register(collection: AuthController())
    
    let protected = app.grouped(JWTMiddleware())
    protected.get("protectedRoute", use: protectedHandler)

}

func protectedHandler(req: Request) throws -> String {
    // Этот обработчик будет вызываться только для запросов с действительным JWT
    let payload = try req.auth.require(TokenPayload.self)
    // Используйте данные из payload по мере необходимости
    return "Доступ к защищенному контенту разрешен"
}
