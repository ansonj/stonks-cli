import Foundation

struct ResetPendingBuysFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        print("This will reallocate your buying power (less profit) according to your reinvestment splits.")
        print("Pending buys will be reset.")
        let confirmation = Prompt.readBoolean(withMessage: "Are you sure?")
        if confirmation {
            DatabaseIO.resetPendingBuys(inPath: configFile.databasePath())
        }
        print()
    }
}
