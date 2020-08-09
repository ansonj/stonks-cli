import Foundation

// TODO: Move this to a separate file
protocol Flow {
    func run()
}

struct SetupFlow: Flow {
    let configFileUrl: URL
    
    func run() {
        ensureConfigFileExists(atFileUrl: configFileUrl)
        ensureIexCloudApiKeyExists(atFileUrl: configFileUrl)
    }
    
    private func ensureConfigFileExists(atFileUrl fileUrl: URL) {
        if !FileManager.default.isReadableFile(atPath: fileUrl.path) {
            Prompt.confirmContinue(withMessage: "Create config file at '\(fileUrl)'?")
            let emptyJson = "{}"
            guard let emptyJsonData = emptyJson.data(using: .utf8) else {
                Prompt.exitStonks(withMessage: "Couldn't prepare empty JSON data.")
            }
            do {
                try emptyJsonData.write(to: fileUrl, options: .atomic)
            } catch let writingError {
                Prompt.exitStonks(withMessage: "Error writing empty JSON data: \(writingError)")
            }
        }
    }
    
    private func ensureIexCloudApiKeyExists(atFileUrl fileUrl: URL) {
        // FIXME: Implement
    }
}
