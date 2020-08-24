import Foundation

//! For best caching results, implementers of this protocol should
//! (a) use an API that provides the best and/or most recent possible price, then
//! (b) set the StockInfo timestamp to the time when that price was last fetched.
//! The timestamp might not be the actual timestamp of the price, but that's not important for caching.
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
