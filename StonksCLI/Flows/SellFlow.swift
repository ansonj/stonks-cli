import Foundation

struct SellFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        let trxnId_string = Prompt.readString(withMessage: "Which ID #?")
        guard let trxnId = Int(trxnId_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(trxnId_string)' to an integer.")
            return
        }
        
        guard let transaction = DatabaseIO.activeTransaction(withId: trxnId) else {
            Prompt.pauseThenContinue(withMessage: "Transaction \(trxnId) is not active.")
            return
        }
        
        let confirmedCorrectSale = Prompt.readBoolean(withMessage: "Selling \(Formatting.string(forDouble: transaction.shares)) shares of \(transaction.ticker), correct?")
        guard confirmedCorrectSale else {
            return
        }
        
        let sellDate_string = Prompt.readDateString()
        let sellDate = DatabaseUtilities.date(fromString: sellDate_string)
        guard transaction.buyDate < sellDate else {
            Prompt.pauseThenContinue(withMessage: "Sell date \(Formatting.friendlyDateString(forDate: sellDate)) is not after buy date \(Formatting.friendlyDateString(forDate: transaction.buyDate)).")
            return
        }
        
        let sellPrice_string = Prompt.readString(withMessage: "What was the selling price per share?")
        guard let sellPrice = Double(sellPrice_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(sellPrice_string)' to a double.")
            return
        }
        
        let revenue = transaction.shares * sellPrice
        let profit = revenue - transaction.investment
        let returnPercentage = profit / transaction.investment
        
        let confirmationMessage = "Sell \(Formatting.string(forDouble: transaction.shares)) shares of \(transaction.ticker) on \(Formatting.friendlyDateString(forDate: sellDate)) at \(Formatting.string(forCurrency: sellPrice)), for a return of \(Formatting.string(forPercentage: returnPercentage))?"
        let confirmed = Prompt.readBoolean(withMessage: confirmationMessage)
        
        if confirmed {
            DatabaseIO.recordSell(path: configFile.databasePath(),
                                  trxnId: trxnId,
                                  sellDate: sellDate_string,
                                  sellPrice: sellPrice,
                                  revenue: revenue,
                                  profit: profit,
                                  returnPercentage: returnPercentage)
        }
        print()
    }
}
