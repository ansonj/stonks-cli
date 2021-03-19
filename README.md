# stonks-cli

Stonks is...

- An implementation of a trading strategy that focuses on regularly taking small amounts of profit (3-5%) while not requiring constant monitoring
- A handy way to save your trades to a sqlite database

Stonks is not...

- A historical price tracker
- A graphing tool
- Capable of making trades for you
- 3x leveraged

## So, what's the strategy?

1. Pick a few index funds or ETFs that have good average returns over time, such as [VOO](https://www.google.com/finance/quote/VOO:NYSEARCA), [SPY](https://www.google.com/finance/quote/SPY:NYSEARCA), [VUG](https://www.google.com/finance/quote/VUG:NYSEARCA), etc. Set percentage goals for each to define your target portfolio. The idea is to set it and (mostly) forget it.
1. Every so often, deposit some capital into your brokerage account. When you have uninvested capital, and a good buying opportunity for a security arises, then buy `$n` worth of shares, where `$n` is the difference between your portfolio goal and current total investment in the security.
1. Assuming a first-in-first-out (FIFO) cost basis, Stonks will show you your current return per purchase. Where brokers will always show you your overall or average position, Stonks specifically shows your position _per purchase_, as each purchase will perform differently based on how the market has done since the purchase date.
1. When the oldest purchase of a security reaches a target percentage of return (currently 5%, see [`sellThreshold` in the code](https://github.com/ansonj/stonks-cli/blob/d4b71505769ca74166691b1565b962dcdcdd09f0/StonksCLI/main.swift#L5)), sell those shares and take the 5% profit. The profit is yours immediately and can be withdrawn; the capital is marked for reinvestment and the cycle continues at step 2.

## Installation and setup

1. Build and extract the executable. You can run the tool from Xcode itself (Cmd+R), but the output has colored text that only appears when running from a terminal.
    1. Open the Xcode project.
    1. Choose Project > Archive.
    1. Open the Archives list if it doesn't open already (Window > Organizer, choose StonksCLI > Archives).
    1. Click Distribute Content, choose Build Products, and save it somewhere.
    1. Inside the saved folder, navigate to `Products/usr/local/bin`.
    1. Move the `StonksCLI` binary somewhere so it's in your `$PATH`, or somewhere where you can run it easily.
1. Set up a brokerage account for yourself, such as with [Robinhood](https://join.robinhood.com/ansonj14) or [Fidelity](https://www.fidelity.com).
    1. Stonks is designed to be a mirror of your entire account history, so it's easiest to use with new accounts or with accounts containing only a few trades.
    1. Ensure that your account is set up to use a FIFO cost basis.
1. Stonks uses the free IEX Cloud API to provide price data, so you'll need to [register for an IEX Cloud account](https://iexcloud.io/cloud-login#/register) and then [retrieve your "publishable" API token](https://iexcloud.io/console/tokens). Stonks does not make a large number of API calls, so API usage incurred by an individual using Stonks should be well within IEX Cloud's free credit limits.

## How to use

1. Running Stonks will guide you through setup, which will create a file at `~/.config/stonks-cli.json`, then prompt you for your IEX Cloud token and sqlite database location. If the database doesn't exist yet, it will be created.
1. Stonks will create some sample portfolio goals (a.k.a. "splits") for you. To edit these, you'll need to edit the `reinvestment_splits` table in your database manually using the `sqlite3` tool or similar. Editing portfolio goals via Stonks is not currently supported, but you can view your goals and current portfolio summary via the `view (p)ortfolio goals` main menu item.
1. Record a deposit using `(t)ransfer` > `(d)eposit`. Stonks' main view will then show you that you have "pending buys," meaning your cash ready for reinvestment has been distributed to your portfolio goals.
1. Record a purchase using `(b)uy` on the main menu. If you enter a security that's in your portfolio goals, Stonks will suggest the amount to invest, but it won't prevent you from going all-in on [GME](https://www.google.com/finance/quote/GME:NYSE) if that's your style.
1. The main view will now show your purchase, including the current return and price target (+5%).
1. When you're ready, use `(s)ell` to record a sale. The profit will be added to your "profit not transferred" until you choose to withdraw it, and the original investment amount will be added to the current pending buy total for the security.
