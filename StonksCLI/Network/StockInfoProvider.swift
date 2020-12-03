import Foundation

struct StockInfo {
    let ticker: String
    let companyName: String
    let price: Double
    let todaysChangePercentage: Double
    let timestamp: Date
}
extension StockInfo {
    static var errorInfo = StockInfo(ticker: Utilities.errorString,
                                     companyName: Utilities.errorString,
                                     price: 0,
                                     todaysChangePercentage: 0,
                                     timestamp: Date(timeIntervalSince1970: 0))
}

protocol StockInfoProvider {
    func fetchInfoSynchronously(forTickers tickers: Set<String>) -> [StockInfo]
}
