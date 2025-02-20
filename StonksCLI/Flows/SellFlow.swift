import Foundation

struct SellFlow: Flow {
    let configFile: ConfigFile
    let priceCache: PriceCache
    
    func run() {
        let allActiveTransactions = FlowUtilities.activeTransactionDisplayRows(fromPath: configFile.databasePath(), usingPriceCache: priceCache)
        var oldestActiveTransactions = [ActiveDisplayRow]()
        allActiveTransactions.forEach { trxn in
            let existingSymbols = oldestActiveTransactions.map { $0.ticker }
            if !existingSymbols.contains(trxn.ticker) {
                oldestActiveTransactions.append(trxn)
            }
        }
        let reinvestmentSymbols = DatabaseIO.reinvestmentSplits(fromPath: configFile.databasePath()).map { $0.ticker }
        let (headers, rows) = FlowUtilities.tableHeadersAndRows(forDisplayRows: oldestActiveTransactions,
                                                                markSellableRows: false,
                                                                reinvestmentSymbols: reinvestmentSymbols)
        let table = Table.renderTable(withHeaders: headers, rows: rows)
        print(table)
        
        let trxnId_string = Prompt.readString(withMessage: "Which ID #?")
        guard let trxnId = Int(trxnId_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(trxnId_string)' to an integer.")
            return
        }
        guard oldestActiveTransactions.map({ $0.trxnId }).contains(trxnId) else {
            let matchingTransactions = allActiveTransactions.filter { $0.trxnId == trxnId }
            assert(matchingTransactions.count > 0)
            let symbol = matchingTransactions.first?.ticker ?? Utilities.errorString
            Prompt.pauseThenContinue(withMessage: "You can't sell #\(trxnId) yet. There is an older \(symbol) that you need to sell first.")
            return
        }
        
        // We should have the transaction already in oldestActiveTransactions as an ActiveDisplayRow,
        // but the rest of this code takes an ActiveBuyTransaction and I don't want to rewrite it.
        // Fetching the raw transaction from the database is a helpful consistency check anyway.
        guard let transaction = DatabaseIO.activeTransaction(fromPath: configFile.databasePath(),
                                                             withId: trxnId)
        else {
            Prompt.pauseThenContinue(withMessage: "Transaction \(trxnId) is not active.")
            return
        }
        
        let shareCount: String
        // TODO: Not great to have another hardcoded dependency on .bitcoinSymbol here
        if transaction.ticker == BlockchainAPI.bitcoinSymbol {
            shareCount = Formatting.string(forLongDouble: transaction.shares)
        } else {
            shareCount = Formatting.string(forNormalDouble: transaction.shares)
        }
        let confirmedCorrectSale = Prompt.readBoolean(withMessage: "Selling \(shareCount) shares of \(transaction.ticker), correct?")
        guard confirmedCorrectSale else {
            return
        }
        
        let sellDate_string = Prompt.readDateString()
        let sellDate = DatabaseUtilities.date(fromString: sellDate_string)
        guard transaction.buyDate < sellDate else {
            Prompt.pauseThenContinue(withMessage: "Sell date \(Formatting.friendlyDateString(forDate: sellDate)) is not after buy date \(Formatting.friendlyDateString(forDate: transaction.buyDate)).")
            return
        }
        let heldDays = Utilities.daysBetween(transaction.buyDate, and: sellDate)
        
        // TODO: Deduplicate this calculation with the one in MainFlow.swift?
        let targetPrice = transaction.costBasis * (1 + sellThreshold)
        do {
            let rows = [
                ["Shares", shareCount],
                ["Buy date", Formatting.friendlyDateString(forDate: transaction.buyDate)],
                ["Age", "\(transaction.age) days"],
                ["Cost basis", Formatting.string(forCurrency: transaction.costBasis)],
                ["+\(Formatting.string(forPercentage: sellThreshold)) target", Formatting.string(forCurrency: targetPrice)]
            ]
            let table = Table.renderQuickTable(withRows: rows)
            print(table)
        }
        let sellPrice_string = Prompt.readString(withMessage: "What was the average selling price per share ($)?")
        guard let sellPrice = Double(sellPrice_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(sellPrice_string)' to a double.")
            return
        }
        
        let revenue = transaction.shares * sellPrice
        let profit = revenue - transaction.investment
        let returnPercentage = profit / transaction.investment
        
        do {
            let rows = [
                ["Symbol", transaction.ticker],
                ["Shares", shareCount],
                ["Sell date", Formatting.friendlyDateString(forDate: sellDate)],
                ["Sell price", Formatting.string(forCurrency: sellPrice)],
                ["Revenue", Formatting.string(forCurrency: revenue)],
                ["Profit ($)", Formatting.string(forCurrency: profit)],
                ["Profit (%)", Formatting.string(forPercentage: returnPercentage)]
            ]
            let table = Table.renderQuickTable(withRows: rows)
            print(table)
        }
        let confirmed = Prompt.readBoolean(withMessage: "Record sale?")
        
        if confirmed {
            DatabaseIO.recordSell(path: configFile.databasePath(),
                                  trxnId: trxnId,
                                  ticker: transaction.ticker,
                                  investment: transaction.investment,
                                  sellDate: sellDate_string,
                                  sellPrice: sellPrice,
                                  revenue: revenue,
                                  profit: profit,
                                  returnPercentage: returnPercentage,
                                  heldDays: heldDays)
        }
        print()
    }
}
