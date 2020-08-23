import Foundation

struct ActiveBuyTransaction {
    let trxnId: Int
    let ticker: String
    let investment: Double
    let shares: Double
    let buyDate: Date
    let costBasis: Double
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
