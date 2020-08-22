import Foundation

struct ActiveBuyTransaction {
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
