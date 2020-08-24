import Foundation

struct StockInfo {
    let ticker: String
    let companyName: String
    let price: Double
    let todaysChangePercentage: Double
    let timestamp: Date
}

protocol StockInfoProvider {
    func fetchInfoSynchronously(forTickers tickers: Set<String>) -> [StockInfo]
}
