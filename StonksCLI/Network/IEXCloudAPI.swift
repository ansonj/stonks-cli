import Foundation

struct IexCloudApi: StockInfoProvider {
    let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
        Logger.log("Data provided by IEX Cloud (https://iexcloud.io)")
    }
    
    func fetchInfoSynchronously(forTickers tickers: Set<String>) -> [StockInfo] {
        // https://iexcloud.io/docs/api/#cryptocurrency-symbols
        // For now, we only care about Bitcoin.
        let cryptocurrencySymbols: [String: String] = [ "BTCUSD": "Bitcoin" ]
        
        let cryptoSymbolsToRequest = tickers.intersection(cryptocurrencySymbols.keys)
        let traditionalSymbolsToRequest = tickers.subtracting(cryptoSymbolsToRequest)
        
        let cryptoResults = fetchCryptocurrencySymbols(cryptoSymbolsToRequest, withSymbolNames: cryptocurrencySymbols)
        let traditionalResults = fetchTraditionalSymbols(traditionalSymbolsToRequest)
        
        return traditionalResults + cryptoResults
    }
    
    private func fetchTraditionalSymbols(_ symbols: Set<String>) -> [StockInfo] {
        // https://iexcloud.io/docs/api/#quote
        let domain = apiKey.starts(with: "T") ? "sandbox" : "cloud"
        guard var urlBuilder = URLComponents(string: "https://\(domain).iexapis.com/stable/stock/market/batch") else {
            Prompt.exitStonks(withMessage: "Couldn't build URLComponents for traditional symbol")
        }
        
        // TODO: Enforce limit of 100 symbols per request
        let symbolsQueryItem = symbols.joined(separator: ",")
        urlBuilder.queryItems = [
            URLQueryItem(name: "symbols", value: symbolsQueryItem),
            URLQueryItem(name: "types", value: "quote"),
            URLQueryItem(name: "token", value: apiKey)
        ]
        
        guard let url = urlBuilder.url else {
            Prompt.exitStonks(withMessage: "Couldn't get url from components: \(urlBuilder)")
        }
        
        var results = [StockInfo]()
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
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
            for quoteWrapper in jsonDict.values {
                guard let quoteWrapperDict = quoteWrapper as? [String: Any] else { continue }
                guard let quoteDict = quoteWrapperDict["quote"] as? [String: Any] else { continue }
                
                guard let ticker = quoteDict["symbol"] as? String else { continue }
                guard let name = quoteDict["companyName"] as? String else { continue }
                guard let price = quoteDict["latestPrice"] as? Double else { continue }
                // changePercent may be null
                let changePercent = (quoteDict["changePercent"] as? Double) ?? 0
                // The response also includes a `latestUpdate`, but depending on market hours, etc., this could be a day or two old.
                // We'll assume that the API is doing the best it can to get us a fresh value,
                // and cache with a timestamp of now.
                let info = StockInfo(ticker: ticker,
                                     companyName: name,
                                     price: price,
                                     todaysChangePercentage: changePercent,
                                     timestamp: Date())
                results.append(info)
            }
        })
        
        task.resume()
        semaphore.wait()
        
        if results.count != symbols.count {
            print("Something went wrong while fetching traditional prices: \(symbols)")
        }
        return results
    }
    
    private func fetchCryptocurrencySymbols(_ symbols: Set<String>, withSymbolNames symbolNames: [String: String]) -> [StockInfo] {
        // https://iexcloud.io/docs/api/#cryptocurrency-price
        let domain = apiKey.starts(with: "T") ? "sandbox" : "cloud"

        var results = [StockInfo]()
        for symbol in symbols {
            guard var urlBuilder = URLComponents(string: "https://\(domain).iexapis.com/stable/crypto/\(symbol)/price") else {
                Prompt.exitStonks(withMessage: "Couldn't build URLComponents for crypto symbol '\(symbol)'")
            }
            urlBuilder.queryItems = [
                URLQueryItem(name: "token", value: apiKey)
            ]
            guard let url = urlBuilder.url else {
                Prompt.exitStonks(withMessage: "Couldn't get url from components: \(urlBuilder)")
            }
            let semaphore = DispatchSemaphore(value: 0)
            let task = URLSession.shared.dataTask(with: url, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
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
                guard let symbol = jsonDict["symbol"] as? String else { return }
                guard let price = (jsonDict["price"] as? String).flatMap({ Double($0) }) else { return }
                let info = StockInfo(ticker: symbol,
                                     companyName: symbolNames[symbol, default: "Unknown"],
                                     price: price,
                                     todaysChangePercentage: 0,
                                     timestamp: Date())
                results.append(info)
            })
            
            task.resume()
            semaphore.wait()
        }
        
        if results.count != symbols.count {
            print("Something went wrong while fetching crypto prices: \(symbols)")
        }
        return results
    }
}
