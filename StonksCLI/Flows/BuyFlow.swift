import Foundation

struct BuyFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        let symbol = Prompt.readString(withMessage: "What ticker symbol?")
        
        let investment_string = Prompt.readString(withMessage: "How much ($)?")
        guard let investment = Double(investment_string) else {
            print("Couldn't convert '\(investment_string)' to a double.")
            return
        }
        
        let shares_string = Prompt.readString(withMessage: "How many shares?")
        guard let shares = Double(shares_string) else {
            print("Couldn't convert '\(shares_string)' to a double.")
            return
        }
        
        var date = Prompt.readString(withMessage: "What date? Format as YYYY-MM-DD, or leave blank for today.")
        if date == "" {
            date = DatabaseUtilities.string(fromDate: Date())
        }
        let dateStringForConfirmation = { () -> String in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM dd, yyyy"
            return dateFormatter.string(from: DatabaseUtilities.date(fromString: date))
        }()
        
        let costBasis = investment / shares
        
        let confirmationMessage = "Buy \(shares) shares of \(symbol) for \(formatCurrency(investment)) on \(dateStringForConfirmation), for a cost basis of \(formatCurrency(costBasis))?"
        let confirmed = Prompt.readBoolean(withMessage: confirmationMessage)
        
        if confirmed {
            DatabaseIO.recordBuy(path: configFile.databasePath(),
                                 ticker: symbol,
                                 investment: investment,
                                 shares: shares,
                                 date: date)
        }
        print()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let number = NSNumber(value: amount)
        return formatter.string(from: number) ?? "$?.??"
    }
}
