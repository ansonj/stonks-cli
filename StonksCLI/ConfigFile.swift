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
    
    // FIXME: Use property wrappers instead?
    func iexCloudApiKey() -> String {
        guard let jsonFileContents = try? Data(contentsOf: configFileUrl) else {
            Prompt.exitStonks(withMessage: "Couldn't load config file.")
        }
        guard let configDictionary = try? JSONDecoder().decode([String: String].self, from: jsonFileContents) else {
            Prompt.exitStonks(withMessage: "Couldn't parse JSON from config file.")
        }
        
        let iexCloudApiKey_key = "iexCloudApiKey"
        return configDictionary[iexCloudApiKey_key] ?? ""
    }
    
    func setIexCloudApiKey(_ newValue: String) {
        guard let jsonFileContents = try? Data(contentsOf: configFileUrl) else {
            Prompt.exitStonks(withMessage: "Couldn't load config file.")
        }
        guard var configDictionary = try? JSONDecoder().decode([String: String].self, from: jsonFileContents) else {
            Prompt.exitStonks(withMessage: "Couldn't parse JSON from config file.")
        }
        
        let iexCloudApiKey_key = "iexCloudApiKey"
        configDictionary[iexCloudApiKey_key] = newValue
        
        guard let newData = try? JSONEncoder().encode(configDictionary) else {
            Prompt.exitStonks(withMessage: "Couldn't encode updated JSON data.")
        }
        do {
            try newData.write(to: configFileUrl, options: .atomic)
        } catch let writingError {
            Prompt.exitStonks(withMessage: "Error writing JSON data with new IEX Cloud API key: \(writingError)")
        }
    }
    
    func ensureIexCloudApiKeyExists() {
        if iexCloudApiKey() == "" {
            print("No IEX Cloud API key found.")
            print("Create an account if needed: https://iexcloud.io/cloud-login#/register")
            let newKey = Prompt.readString(withMessage: "Enter your API key:")
            setIexCloudApiKey(newKey)
        }
    }
}
