import Foundation

struct BlockchainAPI {
    static var bitcoinSymbol = "BTC-USD"
    static var bitcoinName = "Bitcoin"
    
    static func bitcoinStockInfo() -> StockInfo {
        guard let url = URL(string: "https://api.blockchain.com/v3/exchange/tickers/\(bitcoinSymbol)") else {
            Prompt.exitStonks(withMessage: "Couldn't build URL for Bitcoin API request")
        }
        
        var result: StockInfo? = nil
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url) { (data: Data?, response: URLResponse?, error: Error?) in
            defer {
                semaphore.signal()
            }
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data
            else {
                // TODO: Print the error, maybe? (also below), any early return
                return
            }
            
            guard let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return
            }
            guard (jsonDict["symbol"] as? String) == bitcoinSymbol else { return }
            guard let priceNow = jsonDict["last_trade_price"] as? Double else { return }
            guard let price24HoursAgo = jsonDict["price_24h"] as? Double else { return }
            let changePercent: Double
            if price24HoursAgo != 0 {
                changePercent = (priceNow - price24HoursAgo) / price24HoursAgo
            } else {
                changePercent = 0
            }
            result = StockInfo(ticker: bitcoinSymbol,
                               companyName: bitcoinName,
                               price: priceNow,
                               todaysChangePercentage: changePercent,
                               timestamp: Date())
        }
        
        task.resume()
        semaphore.wait()
        
        if result == nil {
            print("Something went wrong while fetching Bitcoin info")
        }
        return result ?? StockInfo.errorInfo
    }
}
