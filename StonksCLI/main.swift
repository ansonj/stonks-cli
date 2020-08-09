import Foundation

let configFileUrl = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config", isDirectory: true)
    .appendingPathComponent("stonks-cli.json")

let setup = SetupFlow(configFileUrl: configFileUrl)
setup.run()
