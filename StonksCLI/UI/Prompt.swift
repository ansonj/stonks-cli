import Foundation

struct Prompt {
    static func confirmContinueOrAbort(withMessage message: String) {
        let shouldContinue = readBoolean(withMessage: message)
        guard shouldContinue else {
            Logger.log("Aborting.")
            exit(0)
        }
    }
    
    static func pauseThenContinue(withMessage message: String? = nil) {
        if let message = message {
            print(message)
        }
        _ = Prompt.readString(withMessage: "Press Enter to continue...")
    }
    
    static func readBoolean(withMessage message: String) -> Bool {
        print(message)
        print("Y/n> ", terminator: "")
        let response = readLine() ?? ""
        return !response.starts(with: "n")
    }
    
    static func readString(withMessage message: String) -> String {
        print(message)
        print("> ", terminator: "")
        let response = readLine() ?? ""
        return response
    }
    
    static func readSymbolString(withMessage message: String) -> String {
        let originalInput = readString(withMessage: message)
        return originalInput.uppercased()
    }
    
    static func readDateString() -> String {
        var date = Prompt.readString(withMessage: "What date? Format as YYYY-MM-DD, or leave blank for today.")
        // TODO: Validate date input
        if date == "" {
            date = DatabaseUtilities.string(fromDate: Date())
        }
        return date
    }
    
    static func exitStonks(withMessage message: String?, code: Int32 = 1) -> Never {
        if let message = message {
            Logger.log(message)
        }
        exit(code)
    }
}
