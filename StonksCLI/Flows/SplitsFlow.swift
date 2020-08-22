struct SplitsFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        // At some point, this flow might support editing splits. Maybe.
        dumpSplits()
        print("Edit these by modifying the reinvestment_splits table in your database.")
        _ = Prompt.readString(withMessage: "Continue?")
        print()
    }
    
    private func dumpSplits() {
        let splits = DatabaseIO.reinvestmentSplits(fromPath: configFile.databasePath())
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
                TableCell(Formatting.string(forDouble: $0.weight)),
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
