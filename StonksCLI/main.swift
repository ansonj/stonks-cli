import Foundation

// TODO: Make these settings in ConfigFile
let almostReadyToSellThreshold = 3.5 / 100.0
let sellThreshold = 5 / 100.0

let databasePathOverride: String?
if CommandLine.arguments.count > 1 {
    databasePathOverride = CommandLine.arguments[1]
} else {
    databasePathOverride = nil
}
let configFileUrl = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config", isDirectory: true)
    .appendingPathComponent("stonks-cli.json")
let configFile = ConfigFile(configFileUrl: configFileUrl,
                            databasePathOverride: databasePathOverride)

let setup = SetupFlow(configFile: configFile)
setup.run()

let iexCloudApi = IexCloudApi(apiKey: configFile.iexCloudApiKey())
let priceCache = InMemoryPriceCache(stockInfoProvider: iexCloudApi)

let main = MainFlow(configFile: configFile,
                    priceCache: priceCache)
main.run()
