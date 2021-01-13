import Foundation

struct TransferFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        print("What kind of transfer?")
        print("    (d)eposit")
        print("    (w)ithdraw available profit")
        print("    record di(v)idend")
        print("    record (i)nterest")
        print("    (c)ancel")
        print()
        let selection = Prompt.readString(withMessage: "Choose action:")
        switch selection.first {
        case "d":
            runDepositFlow()
            return
        case "w":
            runWithdrawalFlow()
            return
        case "v":
            runDividendFlow()
            return
        case "i":
            runInterestFlow()
            return
        default:
            return
        }
    }
    
    private func runDepositFlow() {
        let amount_string = Prompt.readString(withMessage: "How much ($)?")
        guard let amount = Double(amount_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(amount_string)' to a double.")
            return
        }
        
        let date = Prompt.readDateString()
        let dateStringForConfirmation = Formatting.friendlyDateString(forDatabaseDateString: date)
        
        let confirmationMessage = "Deposit \(Formatting.string(forCurrency: amount)) on \(dateStringForConfirmation)?"
        let confirmed = Prompt.readBoolean(withMessage: confirmationMessage)
        if confirmed {
            DatabaseIO.recordDeposit(path: configFile.databasePath(),
                                     amount: amount,
                                     date: date)
        }
        print()
    }
    
    private func runWithdrawalFlow() {
        let profitNotTransferred = DatabaseIO.profitNotTransferred(fromPath: configFile.databasePath())
        let promptMessage: String
        if profitNotTransferred <= 0 {
            promptMessage = "Your current profit waiting to be transferred is \(Formatting.string(forCurrency: profitNotTransferred)). If you withdraw now, you'll be removing capital.\nWithdraw how much ($)?"
        } else {
            promptMessage = "Withdraw how much ($)? Leave blank for \(Formatting.string(forCurrency: profitNotTransferred)), your current profit waiting to be transferred."
        }
        let amount_string = Prompt.readString(withMessage: promptMessage)
        let withdrawalAmount: Double
        if amount_string == "" {
            let roundedProfitNotTransferred = (profitNotTransferred * 100).rounded() / 100
            withdrawalAmount = roundedProfitNotTransferred
        } else if let parsedAmount = Double(amount_string) {
            withdrawalAmount = parsedAmount
        } else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(amount_string)' to a double.")
            return
        }
        let minimumWithdrawalAmount = 0.01
        guard withdrawalAmount >= minimumWithdrawalAmount else {
            Prompt.pauseThenContinue(withMessage: "You can't withdraw less than \(Formatting.string(forCurrency: minimumWithdrawalAmount)).")
            return
        }
        
        let date = Prompt.readDateString()
        let dateStringForConfirmation = Formatting.friendlyDateString(forDatabaseDateString: date)
        
        let confirmationMessage = "Withdraw \(Formatting.string(forCurrency: withdrawalAmount)) on \(dateStringForConfirmation)?"
        let confirmed = Prompt.readBoolean(withMessage: confirmationMessage)
        if confirmed {
            DatabaseIO.recordWithdrawal(path: configFile.databasePath(),
                                        amount: withdrawalAmount,
                                        date: date)
        }
        print()
    }
    
    private func runDividendFlow() {
        let symbol = Prompt.readString(withMessage: "What symbol paid a dividend?")
        
        let amount_string = Prompt.readString(withMessage: "How much ($)?")
        guard let amount = Double(amount_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(amount_string)' to a double.")
            return
        }
        
        let date = Prompt.readDateString()
        let dateStringForConfirmation = Formatting.friendlyDateString(forDatabaseDateString: date)
        
        let confirmationMessage = "Record dividend of \(Formatting.string(forCurrency: amount)) from \(symbol) on \(dateStringForConfirmation)?"
        let confirmed = Prompt.readBoolean(withMessage: confirmationMessage)
        if confirmed {
            DatabaseIO.recordDividend(path: configFile.databasePath(),
                                      amount: amount,
                                      date: date,
                                      symbol: symbol)
        }
        print()
    }
    
    private func runInterestFlow() {
        let amount_string = Prompt.readString(withMessage: "How much cash management interest did you get ($)?")
        guard let amount = Double(amount_string) else {
            Prompt.pauseThenContinue(withMessage: "Couldn't convert '\(amount_string)' to a double.")
            return
        }
        
        let date = Prompt.readDateString()
        let dateStringForConfirmation = Formatting.friendlyDateString(forDatabaseDateString: date)
        
        let confirmationMessage = "Record cash management interest of \(Formatting.string(forCurrency: amount)) on \(dateStringForConfirmation)?"
        let confirmed = Prompt.readBoolean(withMessage: confirmationMessage)
        if confirmed {
            DatabaseIO.recordInterest(path: configFile.databasePath(),
                                      amount: amount,
                                      date: date)
        }
        print()
    }
}
