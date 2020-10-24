# stonks-cli

Stonks is...

- A handy way to save your trades to a sqlite database
- ...

Stonks is not...

- A historical price tracker
- A graphing tool
- Capable of making trades for you
- 3x leveraged

## How to use

Join [Robinhood](https://join.robinhood.com/ansonj14), etc.

## Possible future features

- Some kind of version number support
    - If this is ever going to be public-facing, people need a way to know what version they're running.
- A completed `README.md` with usage instructions
- Print current total average return, just for fun
- Clean up `TODO`s
- Implement caching of prices/names in the database
- Implement a stats view
    - Fastest to reach 5% (or whatever your sell threshold is)
        - Or, just fastest returns in general?
    - Best returns of all time, not including things you haven't sold
    - Longest holds of all time (including things you haven't sold yet?)
    - Average hold length
    - Lifetime return percentage
    - Are you beating the market? (pick a symbol like SPY, show if your lifetime return beats it)
- Support for buying for $0
- Implement transfer > withdraw to withdraw your total profit
- Implement transfer > interest (direct to profit)
- An about screen with ASCII art
- Implement customizable settings, stored in the database
    - Sell threshold, and almost-ready threshold
    - Quote data staleness interval (maybe)
- Edit splits from the CLI
- Implement selling portions of buys, if this is even desired
- Cache the sum of transfers table (or any other stats) for performance?
