import Foundation

struct StatementsFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        // 2020-07 is used in honor of the month in which I started investing
        let yearMonthString = Prompt.readString(withMessage: "What month would you like to reconcile (e.g., '2020-07')?")
        let statementEntries = DatabaseIO.allStatementEntries(fromPath: configFile.databasePath(), forMonth: yearMonthString)
        print()
        
        let headers = [
            HeaderCell("ID #", alignment: .right),
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Activity", alignment: .left),
            HeaderCell("Date", alignment: .right),
            HeaderCell("Qty", alignment: .right),
            HeaderCell("Price", alignment: .right),
            HeaderCell("Debit", alignment: .right),
            HeaderCell("Credit", alignment: .right),
            HeaderCell("Rec #", alignment: .right),
            HeaderCell("Cleared", alignment: .left)
        ]
        
        while true {
            let rows = statementEntries.map { row -> [TableCell] in
                let sharesDescription: String
                if let rowShares = row.shares {
                    if row.activity == .crypto {
                        sharesDescription = Formatting.string(forLongDouble: rowShares)
                    } else {
                        sharesDescription = Formatting.string(forNormalDouble: rowShares)
                    }
                } else {
                    sharesDescription = ""
                }
                let costBasisDescription: String = row.costBasis.map(Formatting.string(forCurrency:)) ?? ""
                return [
                    TableCell(row.trxnId?.description ?? ""),
                    TableCell(row.symbol),
                    TableCell(row.activity.description),
                    TableCell(Formatting.shortDateString(forDate: row.date)),
                    TableCell(sharesDescription),
                    TableCell(costBasisDescription),
                    TableCell(row.amount < 0 ? Formatting.string(forCurrency: row.amount * -1) : ""),
                    TableCell(row.amount > 0 ? Formatting.string(forCurrency: row.amount) : ""),
                    TableCell(row.reconciliationId.description),
                    TableCell(row.reconciled ? "X" : "")
                ]
            }
            let table = Table.renderTable(withHeaders: headers, rows: rows)
            print(table)
            let clearedCount = statementEntries.filter({ $0.reconciled }).count
            print("Cleared ", clearedCount, "/", statementEntries.count, (clearedCount == statementEntries.count ? " \u{2705}" : ""))
            print()
            
            let inputString = Prompt.readString(withMessage: "Enter Rec # to mark as cleared/uncleared, or 0 to exit.")
            guard let recId = Int(inputString), recId > 0 else {
                break
            }
            let index = recId - 1
            guard index < statementEntries.count else {
                continue
            }
            statementEntries[index].reconciled.toggle()
        }
    }
}
