import Foundation

protocol Flow {
    func run()
}

struct FlowUtilities {
    static func activeTransactionDisplayRows(fromPath path: String, usingPriceCache priceCache: PriceCache) -> [ActiveDisplayRow] {
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: configFile.databasePath())
        
        priceCache.primeCache(forTickers: Set<String>(activeTransactions.map({ $0.ticker })))
        
        var displayRows = activeTransactions.map {
            ActiveDisplayRow(activeBuyTransaction: $0, priceSource: priceCache)
        }
        // Fill in averageReturnPercentage, which we can't calculate individually
        displayRows.forEach { row in
            let matchingTrxns = displayRows.filter { $0.ticker == row.ticker }
            let totalInvestment = matchingTrxns.reduce(into: 0, { $0 += $1.investment })
            let totalValue = matchingTrxns.reduce(into: 0, { $0 += $1.currentValue })
            row.averageReturnPercentage = (totalValue - totalInvestment) / totalInvestment
        }
        displayRows.sort { (lhs: ActiveDisplayRow, rhs: ActiveDisplayRow) -> Bool in
            // return true if lhs should come before rhs
            if lhs.averageReturnPercentage > rhs.averageReturnPercentage {
                return true
            } else if lhs.averageReturnPercentage < rhs.averageReturnPercentage {
                return false
            }
            if lhs.ticker < rhs.ticker {
                return true
            } else if lhs.ticker > rhs.ticker {
                return false
            }
            if lhs.age > rhs.age {
                return true
            } else if lhs.age < rhs.age {
                return false
            }
            return lhs.trxnId < rhs.trxnId
        }
        
        return displayRows
    }
    
    static func tableHeadersAndRows(forDisplayRows displayRows: [ActiveDisplayRow]) -> (headers: [HeaderCell], rows: [[TableCell]]) {
        let colorPercentage = { (p: Double) -> TerminalTextColor in
            if p < 0 {
                return .red
            } else if 0 <= p && p < almostReadyToSellThreshold {
                return .black
            } else if almostReadyToSellThreshold <= p && p < sellThreshold {
                return .yellow
            } else {
                assert(sellThreshold <= p, "Developer or floating point error")
                return .green
            }
        }
        let colorProfit = { (n: Double) -> TerminalTextColor in
            if n < 0 {
                return .red
            } else {
                return .black
            }
        }
        
        let headers = [
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Company Name", alignment: .left),
            HeaderCell("Investment", alignment: .right),
            HeaderCell("Shares", alignment: .right),
            HeaderCell("Cost Basis", alignment: .right),
            HeaderCell("Price Now", alignment: .right),
            HeaderCell("Target", alignment: .right),
            HeaderCell("Return", alignment: .right),
            HeaderCell("ID #", alignment: .right),
            HeaderCell("Profit", alignment: .right),
            HeaderCell("Age", alignment: .right),
            HeaderCell("Avg. Return", alignment: .right),
        ]
        let rows = displayRows.map { row -> [TableCell] in
            let currentReturnColor = colorPercentage(row.currentReturnPercentage)
            let currentProfitColor = colorProfit(row.profit)
            let avgReturnColor = colorPercentage(row.averageReturnPercentage)
            return [
                TableCell(row.ticker, color: currentReturnColor),
                TableCell(row.companyName),
                TableCell(Formatting.string(forCurrency: row.investment)),
                TableCell(Formatting.string(forDouble: row.shares)),
                TableCell(Formatting.string(forCurrency: row.costBasis)),
                TableCell(Formatting.string(forCurrency: row.currentPrice)),
                TableCell(Formatting.string(forCurrency: row.targetPrice), color: currentReturnColor),
                TableCell(Formatting.string(forPercentage: row.currentReturnPercentage), color: currentReturnColor),
                TableCell(row.trxnId.description, color: currentReturnColor),
                TableCell(Formatting.string(forCurrency: row.profit), color: currentProfitColor),
                TableCell(row.age.description),
                TableCell(Formatting.string(forPercentage: row.averageReturnPercentage), color: avgReturnColor)
            ]
        }
        return (headers: headers, rows: rows)
    }
}

class ActiveDisplayRow {
    let trxnId: Int
    let ticker: String
    let companyName: String
    let investment: Double
    let shares: Double
    let costBasis: Double
    let currentPrice: Double
    let targetPrice: Double
    let currentValue: Double // No need to display this one, but it's helpful for math
    let currentReturnPercentage: Double
    let profit: Double
    let age: Int
    var averageReturnPercentage: Double
    
    init(activeBuyTransaction trxn: ActiveBuyTransaction, priceSource: PriceCache) {
        let info = priceSource.info(forTicker: trxn.ticker)
        
        self.trxnId = trxn.trxnId
        self.ticker = trxn.ticker
        self.companyName = info.companyName
        self.investment = trxn.investment
        self.shares = trxn.shares
        self.costBasis = trxn.costBasis
        self.currentPrice = info.price
        self.targetPrice = trxn.costBasis * (1 + sellThreshold)
        self.currentValue = currentPrice * trxn.shares
        self.currentReturnPercentage = (currentValue - investment) / investment
        self.profit = currentValue - investment
        self.age = Utilities.daysBetween(trxn.buyDate, and: Date())
        self.averageReturnPercentage = 0 // Will be filled in later
    }
}
