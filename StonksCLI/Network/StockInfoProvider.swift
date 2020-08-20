import Foundation

struct StockInfo {
    let ticker: String
    let companyName: String
    let price: Double
    let timestamp: Date
}

protocol StockInfoProvider {
    func fetchInfoSynchronously(forTickers tickers: [String]) -> [StockInfo]
}
