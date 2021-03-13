struct SplitsFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        // At some point, this flow might support editing splits. Maybe.
        dumpSplits()
        print("Edit the above goals by modifying the reinvestment_splits table in your database.")
        print()
        dumpPortfolio()
        Prompt.pauseThenContinue()
        print()
    }
    
    private func dumpSplits() {
        let splits = DatabaseIO.reinvestmentSplits(fromPath: configFile.databasePath(), includeCash: true)
        guard splits.count > 0 else {
            Prompt.exitStonks(withMessage: "Somehow, we snuck through to SplitsFlow with no splits defined.")
        }
        
        priceCache.primeCache(forTickers: Set<String>(splits.map({ $0.ticker })))
        // TODO: Maybe sort by weight, then symbol
        let displayRows = splits.map { SplitDisplayRow(split: $0,
                                                       priceSource: priceCache) }
                                .sorted(by: { $0.weight > $1.weight })
        
        let headers = [
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Percentage",alignment: .right),
            HeaderCell("Weight", alignment: .right),
            HeaderCell("Company Name", alignment: .left)
        ]
        let rows = displayRows.map {
            [
                TableCell($0.ticker),
                TableCell(Formatting.string(forPercentage: $0.percentage)),
                TableCell(Formatting.string(forNormalDouble: $0.weight)),
                TableCell($0.companyName)
            ]
        }
        print(Table.renderTable(withHeaders: headers, rows: rows))
        print()
    }
    
    private func dumpPortfolio() {
        let path = configFile.databasePath()
        let activeTransactions = DatabaseIO.activeTransactions(fromPath: path)
        let totalActiveFunds = activeTransactions.map(\.investment).reduce(0, +)
        let splits = DatabaseIO.reinvestmentSplits(fromPath: path, includeCash: true)
        let portfolioGoals = DatabaseIO.portfolioGoals(fromPath: path, includeCash: true)
        
        let symbolsFromTransactions = Set<String>(activeTransactions.map(\.ticker))
        let symbolsFromSplits = Set<String>(splits.map(\.ticker))
        let allSymbols = symbolsFromTransactions.union(symbolsFromSplits)
        
        priceCache.primeCache(forTickers: allSymbols)
        
        var portfolioDisplayRows = allSymbols.map { PortfolioDisplayRow(symbol: $0) }
        for row in portfolioDisplayRows {
            row.companyName = priceCache.info(forTicker: row.symbol).companyName
            row.goalPortfolioPercentage = splits.first(where: { $0.ticker == row.symbol })?.percentage ?? 0
            if row.symbol == Split.cashSignifier {
                row.currentAmount = DatabaseIO.totalPendingBuys(fromPath: path)
            } else {
                row.currentAmount = activeTransactions.filter({ $0.ticker == row.symbol }).map(\.investment).reduce(0, +)
            }
            row.currentPortfolioPercentage = row.currentAmount / totalActiveFunds
            row.goalAmount = portfolioGoals[row.symbol, default: 0]
        }
        // TODO: Maybe also sort by symbol
        portfolioDisplayRows.sort(by: { $0.goalPortfolioPercentage > $1.goalPortfolioPercentage })
        
        let headers = [
            HeaderCell("Symbol", alignment: .left),
            HeaderCell("Goal %", alignment: .right),
            HeaderCell("Goal $", alignment: .right),
            HeaderCell("Current %", alignment: .right),
            HeaderCell("Current $", alignment: .right),
            HeaderCell("Company Name", alignment: .left)
        ]
        let placeholder = "--"
        let formatPercentage = { p -> String in p == 0 ? placeholder : Formatting.string(forPercentage: p) }
        let formatCurrency = { c -> String in c == 0 ? placeholder : Formatting.string(forCurrency: c) }
        let rows = portfolioDisplayRows.map {
            [
                TableCell($0.symbol),
                TableCell(formatPercentage($0.goalPortfolioPercentage)),
                TableCell(formatCurrency($0.goalAmount)),
                TableCell(formatPercentage($0.currentPortfolioPercentage)),
                TableCell(formatCurrency($0.currentAmount)),
                TableCell($0.companyName)
            ]
        }
        print(Table.renderTable(withHeaders: headers, rows: rows))
        print()
    }
}

private struct SplitDisplayRow {
    let ticker: String
    let weight: Double
    let percentage: Double
    let companyName: String
    
    init(split: Split, priceSource: PriceCache) {
        self.ticker = split.ticker
        self.weight = split.weight
        self.percentage = split.percentage
        self.companyName = priceSource.info(forTicker: split.ticker).companyName
    }
}

private class PortfolioDisplayRow {
    let symbol: String
    var companyName: String = ""
    var currentPortfolioPercentage: Double = 0
    var goalPortfolioPercentage: Double = 0
    var currentAmount: Double = 0
    var goalAmount: Double = 0
    
    init(symbol: String) {
        self.symbol = symbol
    }
}
extension PortfolioDisplayRow: CustomStringConvertible {
    var description: String {
        return "\(symbol) currently $\(currentAmount) \(currentPortfolioPercentage)% goal $\(goalAmount) \(goalPortfolioPercentage)%"
    }
}
