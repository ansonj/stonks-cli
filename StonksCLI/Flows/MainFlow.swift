import Foundation

struct MainFlow: Flow {
    let configFile: ConfigFile
    let priceCache: PriceCache
    
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
            case nil:
                // Allow pressing enter to refresh table
                break
            case "b":
                let buy = BuyFlow(configFile: configFile)
                buy.run()
            case "q":
                exit(0)
            default:
                lastInputErrorMessage = "'\(selection)' is not an option"
            }
        }
    }
    
    private func printActiveTable() {
        // TODO: Implement this!
        
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: configFile.databasePath())
        print(activeTransactions)
        
        priceCache.primeCache(forTickers: Set<String>(activeTransactions.map({ $0.ticker })))
        
        print()
    }
    
    private func printMainMenu() {
        print("Main menu")
        print("    (b)uy")
        print("    (q)uit")
        print()
    }
}
