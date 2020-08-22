import Foundation

struct ResetPendingBuysFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        print("Reset pending buys flow goes here.")
        Prompt.pauseThenContinue()
        print()
    }
}
