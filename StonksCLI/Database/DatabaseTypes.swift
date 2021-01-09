import Foundation

struct ActiveBuyTransaction {
    let trxnId: Int
    let ticker: String
    let investment: Double
    let shares: Double
    let buyDate: Date
    let costBasis: Double
    
    var age: Int {
        Utilities.daysBetween(buyDate, and: Date())
    }
}

struct PendingBuy {
    let ticker: String
    let amount: Double
}

struct Split {
    let ticker: String
    let weight: Double
    let percentage: Double
}

class StatementEntry {
    enum Activity {
        case buy
        case sell
        case crypto
        case ach
        case cashDividend
        
        var description: String {
            switch self {
            case .buy:          return "Buy"
            case .sell:         return "Sell"
            case .crypto:       return "Crypto"
            case .ach:          return "ACH"
            case .cashDividend: return "CDIV"
            }
        }
    }
    
    let trxnId: Int?
    let symbol: String
    let activity: Activity
    let date: Date
    let shares: Double?
    let costBasis: Double?
    let amount: Double
    
    var reconciliationId: Int = 0
    var reconciled: Bool = false
    
    init(trxnId: Int?, symbol: String, activity: Activity, date: Date, shares: Double?, costBasis: Double?, amount: Double) {
        self.trxnId = trxnId
        self.symbol = symbol
        self.activity = activity
        self.date = date
        self.shares = shares
        self.costBasis = costBasis
        self.amount = amount
    }
}
