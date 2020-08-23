import Foundation

protocol PriceCache {
    func primeCache(forTickers tickers: Set<String>)
    func info(forTicker ticker: String) -> StockInfo
}

class InMemoryPriceCache: PriceCache {
    let stockInfoProvider: StockInfoProvider
    
    var storage: [String : StockInfo] = [:]
    
    private let cacheInterval_min: Double = 5
    
    init(stockInfoProvider: StockInfoProvider) {
        self.stockInfoProvider = stockInfoProvider
    }
    
    func primeCache(forTickers tickers: Set<String>) {
        let tickersToFetch = tickers.filter {
            guard let existingData = storage[$0] else {
                return true
            }
            // TODO: If markets are closed, return false... but we might need to be smarter than that if there is still a fresher value we can get
            // Maybe if we get the same timestamp twice in a row, give up?
            // Or, just leave it as-is, and don't worry about it
            let ageOfData_min = existingData.timestamp.timeIntervalSinceNow * -1.0 / 60.0
            return ageOfData_min >= cacheInterval_min
        }
        guard tickersToFetch.count > 0 else {
            return
        }
        Logger.log("Fetching latest prices...")
        let freshData = stockInfoProvider.fetchInfoSynchronously(forTickers: tickersToFetch)
        freshData.forEach { info in
            storage[info.ticker] = info
        }
        print()
    }
    
    func info(forTicker ticker: String) -> StockInfo {
        if !storage.keys.contains(ticker) {
            primeCache(forTickers: Set<String>([ticker]))
        }
        let errorInfo = StockInfo(ticker: "ERROR",
                                  companyName: "Error",
                                  price: 0,
                                  timestamp: Date(timeIntervalSince1970: 0))
        return storage[ticker] ?? errorInfo
    }
}
