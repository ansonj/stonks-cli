# stonks-cli

Stonks is ...

- A handy way to save your trades to a sqlite database
- ...

Stonks is not...

- A historical price tracker
- A graphing tool
- 3x leveraged

## Todo

1. Create the main view
    1. Placeholder to print buying power checksum
1. Define flow to record sells (only sell one whole buy at a time)
1. Implement splits table
1. Define flow to edit splits (or maybe do this later, and require manual database split updates?)
1. Implement pending buys table
1. Implement transfers table (amount, date, source)
1. Define flow to input transfers (Deposit, withdraw, dividend, interest)
    1. Implement splitting of deposits
1. Make sure selling is also splitting and sending to pending buys
1. Print buying power checksum
1. Implement selling portions of buys, if this is even desired
1. Implement a stats view
    1. Fastest to reach 5% (or whatever your sell threshold is)
    1. Best returns of all time
    1. Longest holds of all time, including things you haven't sold yet
1. Implement customizable settings, stored in the database
    1. Sell threshold, and almost-ready threshold
    1. Quote data staleness interval
1. Don't forget to use your actual API key before you use it yourself
1. Finish writing this readme
1. Implement database caching of prices?
1. Cache sums of transfers for performance?
1. Clean up `TODO`s
