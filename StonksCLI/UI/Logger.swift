struct Logger {
    static let loggingEnabled = true
    
    static let stonksGlyph = "$/"
    
    static func log(_ message: String) {
        guard loggingEnabled else { return }
        print(stonksGlyph, message)
    }
}
