import Foundation

struct StatementsFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        // 2020-07 is used in honor of the month in which I started investing
        let yearMonthString = Prompt.readString(withMessage: "What month would you like to reconcile (e.g., '2020-07')?")
        let statementEntries = DatabaseIO.allStatementEntries(fromPath: configFile.databasePath(), forMonth: yearMonthString)
        
        print(statementEntries)
        Prompt.pauseThenContinue()
        
        // FIXME: Implement the rest of this flow
    }
}
