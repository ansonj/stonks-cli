struct MainFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        var lastInputErrorMessage: String? = nil
        while true {
            printActiveTable()
            // TODO: Print buying power checksum
            // TODO: Print pending buys list
            printMainMenu()
            let promptString: String
            if lastInputErrorMessage != nil {
                promptString = "Choose action (\(lastInputErrorMessage!)):"
                lastInputErrorMessage = nil
            } else {
                promptString = "Choose action:"
            }
            // TODO: Gracefully handle input of Ctrl+D
            let selection = Prompt.readString(withMessage: promptString)
            switch selection.first {
            case "b":
                let buy = BuyFlow(configFile: configFile)
                buy.run()
            default:
                lastInputErrorMessage = "'\(selection)' is not an option"
            }
        }
    }
    
    private func printActiveTable() {
        // TODO: Implement this!
        print("[Active table WIP]")
        print()
    }
    
    private func printMainMenu() {
        print("Main menu")
        print("    (b)uy")
        print()
    }
}
