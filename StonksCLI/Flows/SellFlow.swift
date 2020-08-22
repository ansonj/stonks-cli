import Foundation

struct SellFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        print("Sell flow goes here.")
        Prompt.pauseThenContinue()
        print()
    }
}
