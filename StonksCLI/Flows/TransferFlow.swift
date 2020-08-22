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
            // TODO: Implement
            print("Withdrawal flow goes here.")
        case "v":
            // TODO: Implement
            print("Recording dividend flow goes here.")
        case "i":
            // TODO: Implement
            print("Recording interest flow goes here.")
        default:
            return
        }
        Prompt.pauseThenContinue()
        print()
    }
    
    private func runDepositFlow() {
        let amount_string = Prompt.readString(withMessage: "How much?")
        guard let amount = Double(amount_string) else {
            print("Couldn't convert '\(amount_string)' to a double.")
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
}
