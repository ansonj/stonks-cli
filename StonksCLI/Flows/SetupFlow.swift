import Foundation

// TODO: Move this to a separate file
protocol Flow {
    func run()
}

struct SetupFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        configFile.ensureIexCloudApiKeyExists()
        configFile.ensureDatabasePathExists()
    }
}
