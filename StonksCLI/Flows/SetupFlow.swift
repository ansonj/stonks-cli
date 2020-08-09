import Foundation

// TODO: Move this to a separate file
protocol Flow {
    func run()
}

struct SetupFlow: Flow {
    let configFilePath: String
    
    func run() {
        ensureConfigFileExists(atPath: configFilePath)
        ensureApiKeyExists(configPath: configFilePath)
    }
    
    private func ensureConfigFileExists(atPath path: String) {
        if !FileManager.default.isReadableFile(atPath: path) {
            Prompt.confirmContinue(withMessage: "Create config file at '\(path)'?")
            let emptyJson = "{}"
            guard let emptyJsonData = emptyJson.data(using: .utf8) else {
                Prompt.exitStonks(withMessage: "Couldn't prepare empty JSON data.")
            }
            let fileUrl = URL(fileURLWithPath: path)
            do {
                try emptyJsonData.write(to: fileUrl, options: .atomic)
            } catch let writingError {
                Prompt.exitStonks(withMessage: "Error writing empty JSON data: \(writingError)")
            }
        }
    }
    
    private func ensureApiKeyExists(configPath: String) {
        // FIXME: Implement
    }
}
