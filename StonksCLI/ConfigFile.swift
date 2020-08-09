import Foundation

struct ConfigFile {
    let configFileUrl: URL
    
    init(configFileUrl: URL) {
        self.configFileUrl = configFileUrl
        
        if !FileManager.default.isReadableFile(atPath: configFileUrl.path) {
            Prompt.confirmContinue(withMessage: "Create config file at '\(configFileUrl)'?")
            let emptyJson = "{}"
            guard let emptyJsonData = emptyJson.data(using: .utf8) else {
                Prompt.exitStonks(withMessage: "Couldn't prepare empty JSON data.")
            }
            do {
                try emptyJsonData.write(to: configFileUrl, options: .atomic)
            } catch let writingError {
                Prompt.exitStonks(withMessage: "Error writing empty JSON data: \(writingError)")
            }
        }
    }
    
    func ensureIexCloudApiKeyExists() {
        guard let jsonFileContents = try? Data(contentsOf: configFileUrl) else {
            Prompt.exitStonks(withMessage: "Couldn't load config file.")
        }
        guard var configDictionary = try? JSONDecoder().decode([String: String].self, from: jsonFileContents) else {
            Prompt.exitStonks(withMessage: "Couldn't parse JSON from config file.")
        }
        
        let iexCloudApiKey_key = "iexCloudApiKey"
        var iexCloudApiKey_value = configDictionary[iexCloudApiKey_key] ?? ""
        if iexCloudApiKey_value == "" {
            print("No IEX Cloud API key found.")
            print("Create an account if needed: https://iexcloud.io/cloud-login#/register")
            iexCloudApiKey_value = Prompt.readString(withMessage: "Enter your API key:")
            configDictionary[iexCloudApiKey_key] = iexCloudApiKey_value
            
            guard let newData = try? JSONEncoder().encode(configDictionary) else {
                Prompt.exitStonks(withMessage: "Couldn't encode updated JSON data.")
            }
            do {
                try newData.write(to: configFileUrl, options: .atomic)
            } catch let writingError {
                Prompt.exitStonks(withMessage: "Error writing JSON data with new IEX Cloud API key: \(writingError)")
            }
        }
    }
}
