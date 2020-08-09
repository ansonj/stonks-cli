import Foundation

let configFileUrl = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config", isDirectory: true)
    .appendingPathComponent("stonks-cli.json")
let configFile = ConfigFile(configFileUrl: configFileUrl)

let setup = SetupFlow(configFile: configFile)
setup.run()
