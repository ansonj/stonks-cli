import Foundation

struct Prompt {
    static func confirmContinueOrAbort(withMessage message: String) {
        let shouldContinue = readBoolean(withMessage: message)
        guard shouldContinue else {
            Logger.log("Aborting.")
            exit(0)
        }
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
    
    static func exitStonks(withMessage message: String?, code: Int32 = 1) -> Never {
        if let message = message {
            Logger.log(message)
        }
        exit(code)
    }
}
