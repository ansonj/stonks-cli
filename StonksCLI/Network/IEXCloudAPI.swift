import Foundation

struct IexCloudApi: StockInfoProvider {
    let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
        print("Data provided by IEX Cloud (https://iexcloud.io)")
    }
    
    func fetchInfoSynchronously(forTickers tickers: [String]) -> [StockInfo] {
        let domain = apiKey.starts(with: "T") ? "sandbox" : "cloud"
        guard var urlBuilder = URLComponents(string: "https://\(domain).iexapis.com/stable/stock/market/batch") else {
            Prompt.exitStonks(withMessage: "Couldn't build URLComponents")
        }
        
        let symbols = tickers.joined(separator: ",")
        urlBuilder.queryItems = [
            URLQueryItem(name: "symbols", value: symbols),
            URLQueryItem(name: "types", value: "quote"),
            URLQueryItem(name: "token", value: apiKey)
        ]
        
        guard let url = urlBuilder.url else {
            Prompt.exitStonks(withMessage: "Couldn't get url from components: \(urlBuilder)")
        }
        
        var results = [StockInfo]()
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            guard error == nil,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let data = data
                else {
                    return
            }

            guard let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return
            }
            for quoteWrapper in jsonDict.values {
                guard let quoteWrapperDict = quoteWrapper as? [String: Any] else { continue }
                guard let quoteDict = quoteWrapperDict["quote"] as? [String: Any] else { continue }
                
                guard let ticker = quoteDict["symbol"] as? String else { continue }
                guard let name = quoteDict["companyName"] as? String else { continue }
                guard let price = quoteDict["latestPrice"] as? Double else { continue }
                guard let timestamp = quoteDict["latestUpdate"] as? Double else { continue }
                let info = StockInfo(ticker: ticker,
                                     name: name,
                                     price: price,
                                     timestamp: Date(timeIntervalSince1970: timestamp / 1000.0))
                results.append(info)
            }
            
            semaphore.signal()
        })
        
        task.resume()
        semaphore.wait()
        
        if results.count != tickers.count {
            print("Something went wrong while fetching prices: \(tickers)")
        }
        return results
    }
}
