struct Logger {
    static let loggingEnabled = true
    
    static func log(_ message: String) {
        guard loggingEnabled else { return }
        print("$/", message)
    }
}
