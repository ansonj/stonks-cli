struct SetupFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        configFile.ensureIexCloudApiKeyExists()
        configFile.ensureDatabasePathExists()
        DatabaseFileManager.verifyDatabase(atPath: configFile.databasePath())
    }
}
