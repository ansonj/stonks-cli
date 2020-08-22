import Foundation

struct TransferFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        print("What kind of transfer?")
        print("    (d)eposit")
        print("    (w)ithdraw available profit")
        print("    record di(v)idend")
        print("    record (i)nterest")
        print("    (c)ancel")
        print()
        let selection = Prompt.readString(withMessage: "Choose action:")
        switch selection.first {
        case "d":
            // TODO: Implement
            print("Deposit flow goes here.")
        case "w":
            // TODO: Implement
            print("Withdrawal flow goes here.")
        case "v":
            // TODO: Implement
            print("Recording dividend flow goes here.")
        case "i":
            // TODO: Implement
            print("Recording interest flow goes here.")
        default:
            return
        }
        _ = Prompt.readString(withMessage: "Continue?")
        print()
    }
}
