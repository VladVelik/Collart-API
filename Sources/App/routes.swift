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
    
    try app.register(collection: UserController())
    try app.register(collection: ProjectController())
    try app.register(collection: OrderController())
    try app.register(collection: SkillController())
    try app.register(collection: ToolController())
    try app.register(collection: InteractionController())
    try app.register(collection: TabController())
    try app.register(collection: SearchController())
    try app.register(collection: MessageController())
    
}

func protectedHandler(req: Request) throws -> String {
    // Этот обработчик будет вызываться только для запросов с действительным JWT
    _ = try req.auth.require(TokenPayload.self)
    // Используйте данные из payload по мере необходимости
    return "Доступ к защищенному контенту разрешен"
}
