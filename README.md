# stonks-cli

Stonks is ...

- A handy way to save your trades to a sqlite database
- ...

Stonks is not...

- A historical price tracker
- A graphing tool
- 3x leveraged

## How to use

Join [Robinhood](https://join.robinhood.com/ansonj14), etc.

## Possible future features

- A completed `README.md` with usage instructions
- Clean up `TODO`s
- Make sure you can't sell out of order
- Implement caching of prices/names in the database
- Implement a stats view
    - Fastest to reach 5% (or whatever your sell threshold is)
        - Or, just fastest returns in general?
    - Best returns of all time, not including things you haven't sold
    - Longest holds of all time (including things you haven't sold yet?)
- Implement transfer > withdraw to withdraw your total profit
- Implement transfer > dividend (split into pending buys)
- Implement transfer > interest (split into pending buys)
- Implement customizable settings, stored in the database
    - Sell threshold, and almost-ready threshold
    - Quote data staleness interval (maybe)
- Edit splits from the CLI
- Implement selling portions of buys, if this is even desired
- Cache the sum of transfers table (or any other stats) for performance?
