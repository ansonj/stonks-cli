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
            return lhs.age > rhs.age
        }
        
        return displayRows
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
