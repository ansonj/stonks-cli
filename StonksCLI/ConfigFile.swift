import Foundation

struct ConfigFile {
    // MARK: Initialization
    
    let configFileUrl: URL
    let databasePathOverride: String?
    
    init(configFileUrl: URL, databasePathOverride: String?) {
        self.configFileUrl = configFileUrl
        if let databasePathOverride = databasePathOverride,
           databasePathOverride != "" {
            self.databasePathOverride = databasePathOverride
        } else {
            self.databasePathOverride = nil
        }
        
        if !FileManager.default.isReadableFile(atPath: configFileUrl.path) {
            Prompt.confirmContinueOrAbort(withMessage: "Create config file at '\(configFileUrl)'?")
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
    
    // TODO: Use property wrappers instead?
    // https://www.swiftbysundell.com/articles/property-wrappers-in-swift/
    
    private let k_iexCloudApiKey = "iexCloudApiKey"
    func iexCloudApiKey() -> String {
        return getString(forKey: k_iexCloudApiKey)
    }
    func setIexCloudApiKey(_ newValue: String) {
        setString(newValue, forKey: k_iexCloudApiKey)
    }
    
    private let k_databasePath = "databasePath"
    func databasePath() -> String {
        if let databasePathOverride = databasePathOverride {
            return databasePathOverride
        } else {
            return getString(forKey: k_databasePath)
        }
    }
    func setDatabasePath(_ newValue: String) {
        setString(newValue, forKey: k_databasePath)
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
    
    // MARK: Public methods
    
    func ensureIexCloudApiKeyExists() {
        if iexCloudApiKey() != "" {
            return
        }
        print("No IEX Cloud API token found.")
        print("Create an account if needed: https://iexcloud.io/cloud-login#/register")
        let newKey = Prompt.readString(withMessage: "Enter your API token:")
        setIexCloudApiKey(newKey)
    }
    
    func ensureDatabasePathExists() {
        if databasePath() != "" {
            return
        }
        print("No database path found.")
        var weGotAValidPath = false
        while !weGotAValidPath {
            let newPath = Prompt.readString(withMessage: "Enter path to new or existing database:")
            let newPathHomeDirReplaced = newPath.replacingOccurrences(of: "~",
                                                                      with: FileManager.default.homeDirectoryForCurrentUser.path)
            print("Does this look correct?")
            weGotAValidPath = Prompt.readBoolean(withMessage: newPathHomeDirReplaced)
            if weGotAValidPath {
                setDatabasePath(newPathHomeDirReplaced)
            }
        }
    }
}
