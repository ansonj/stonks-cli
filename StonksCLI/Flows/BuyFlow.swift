import Foundation

struct BuyFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        let symbol = Prompt.readSymbolString(withMessage: "What ticker symbol?")
        
        let pendingBuys = DatabaseIO.pendingBuys(fromPath: configFile.databasePath())
        let pendingAmountForThisSymbol = pendingBuys.first(where: { $0.ticker == symbol })?.amount
        
        let investment: Double
        if let pendingAmountForThisSymbol = pendingAmountForThisSymbol {
            let investment_string = Prompt.readString(withMessage: "How much to invest ($)? Leave blank for \(Formatting.string(forCurrency: pendingAmountForThisSymbol)).")
            if investment_string == "" {
                investment = pendingAmountForThisSymbol.roundedToNearestCent
            } else if let parsedInvestment = Double(investment_string) {
                investment = parsedInvestment
            } else {
                Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(investment_string)' to a double.")
                return
            }
        } else {
            let investment_string = Prompt.readString(withMessage: "How much to invest ($)?")
            if let parsedInvestment = Double(investment_string) {
                investment = parsedInvestment
            } else {
                Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(investment_string)' to a double.")
                return
            }
        }
        guard investment > 0 && !investment.isBasicallyZero else {
            Prompt.pauseThenContinue(withMessage: "You can't invest $0.")
            return
        }
        
        let date = Prompt.readDateString()
        let dateStringForConfirmation = Formatting.friendlyDateString(forDatabaseDateString: date)
        
        let shares_string = Prompt.readString(withMessage: "How many shares did you purchase?")
        guard let shares = Double(shares_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(shares_string)' to a double.")
            return
        }
        
        let costBasis = investment / shares
        
        do {
            let headers = [
                HeaderCell("", alignment: .left),
                HeaderCell("", alignment: .right)
            ]
            let rows = [
                [TableCell("Symbol"), TableCell(symbol)],
                [TableCell("Shares"), TableCell(shares.description)],
                [TableCell("Investment"), TableCell(Formatting.string(forCurrency: investment))],
                [TableCell("Buy date"), TableCell(dateStringForConfirmation)],
                [TableCell("Cost basis"), TableCell(Formatting.string(forCurrency: costBasis))]
            ]
            let table = Table.renderTable(withHeaders: headers, rows: rows)
            print(table)
        }
        let confirmed = Prompt.readBoolean(withMessage: "Record buy?")
        
        if confirmed {
            DatabaseIO.recordBuy(path: configFile.databasePath(),
                                 ticker: symbol,
                                 investment: investment,
                                 shares: shares,
                                 date: date)
        }
        print()
    }
}
