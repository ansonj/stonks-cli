import Foundation

struct StockInfo {
    let ticker: String
    let name: String
    let price: Double
    let timestamp: Date
}

protocol StockInfoProvider {
    func fetchInfoSynchronously(forTickers tickers: [String]) -> [StockInfo]
}
