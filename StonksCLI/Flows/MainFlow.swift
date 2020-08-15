struct MainFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        while true {
            printActiveTable()
            // TODO: Print buying power checksum
            // TODO: Print pending buys list
            printMainMenu()
            // TODO: Gracefully handle input of Ctrl+D
            let selection = Prompt.readString(withMessage: "Choose action:")
            switch selection.first {
            case "b":
                let buy = BuyFlow(configFile: configFile)
                buy.run()
            default:
                print("Invalid entry '\(selection)'.")
            }
        }
    }
    
    private func printActiveTable() {
        // TODO: Implement this!
        print("[Active table WIP]")
    }
    
    private func printMainMenu() {
        print("Main menu")
        print("    (b)uy")
    }
}
