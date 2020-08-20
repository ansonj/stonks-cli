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
        
        let displayRows = activeTransactions.map {
            ActiveDisplayRow(activeBuyTransaction: $0, priceSource: priceCache)
        }
        // Fill in averageReturnPercentage, which we can't calculate individually
        displayRows.forEach { row in
            let matchingTrxns = displayRows.filter { $0.ticker == row.ticker }
            let totalInvestment = matchingTrxns.reduce(into: 0, { $0 += $1.investment })
            let totalValue = matchingTrxns.reduce(into: 0, { $0 += $1.currentValue })
            row.averageReturnPercentage = (totalValue - totalInvestment) / totalInvestment
        }
        
        print(displayRows.debugDescription)
        
        print()
    }
    
    private func printMainMenu() {
        print("Main menu")
        print("    (b)uy")
        print("    (q)uit")
        print()
    }
}

private class ActiveDisplayRow {
    let ticker: String
    let companyName: String
    let investment: Double
    let currentPrice: Double
    let currentValue: Double // No need to display this one
    let currentReturnPercentage: Double
    let profit: Double
    let age: Int
    var averageReturnPercentage: Double?
    
    init(activeBuyTransaction trxn: ActiveBuyTransaction, priceSource: PriceCache) {
        let info = priceSource.info(forTicker: trxn.ticker)
        
        self.ticker = trxn.ticker
        self.companyName = info.companyName
        self.investment = trxn.investment
        self.currentPrice = info.price
        self.currentValue = currentPrice * trxn.shares
        self.currentReturnPercentage = (currentValue - investment) / investment
        self.profit = currentValue - investment
        self.age = Calendar.current.dateComponents([.day], from: trxn.buyDate, to: Date()).day ?? -1
        self.averageReturnPercentage = nil // Will be filled in later
    }
}
