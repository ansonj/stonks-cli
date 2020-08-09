import Foundation

struct StockInfo {
    let ticker: String
    let name: String
    let price: Double
    let timestamp: Date
}

typealias StockInfoCompletion = (_ info: [StockInfo]) -> Void

protocol StockInfoProvider {
    func fetchInfo(forTickers tickers: [String], completion: StockInfoCompletion)
}
