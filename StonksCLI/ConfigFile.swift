import Foundation

struct ConfigFile {
    // MARK: Initialization
    
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
    
    // MARK: Properties
    
    private func getString(forKey key: String) -> String {
        let configDictionary = readConfigDictionary()
        return configDictionary[key] ?? ""
    }
    
    private func setString(_ newValue: String, forKey key: String) {
        var configDictionary = readConfigDictionary()
        configDictionary[key] = newValue
        setConfigDictionary(configDictionary)
    }
    
    // FIXME: Use property wrappers instead?
    // https://www.swiftbysundell.com/articles/property-wrappers-in-swift/
    
    private let k_iexCloudApiKey = "iexCloudApiKey"
    func iexCloudApiKey() -> String {
        return getString(forKey: k_iexCloudApiKey)
    }
    func setIexCloudApiKey(_ newValue: String) {
        setString(newValue, forKey: k_iexCloudApiKey)
    }
    
    // MARK: Utilities
    
    private func readConfigDictionary() -> [String: String] {
        guard let jsonFileContents = try? Data(contentsOf: configFileUrl) else {
            Prompt.exitStonks(withMessage: "Couldn't load config file.")
        }
        guard let configDictionary = try? JSONDecoder().decode([String: String].self, from: jsonFileContents) else {
            Prompt.exitStonks(withMessage: "Couldn't parse JSON from config file.")
        }
        return configDictionary
    }
    
    private func setConfigDictionary(_ newValue: [String: String]) {
        guard let newData = try? JSONEncoder().encode(newValue) else {
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
