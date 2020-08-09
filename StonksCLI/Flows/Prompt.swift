import Foundation

struct Prompt {
    static func confirmContinue(withMessage message: String) {
        print(message)
        print("Y/n> ", terminator: "")
        let response = readLine() ?? ""
        guard !response.starts(with: "n") else {
            print("Aborting.")
            exit(0)
        }
    }
    
    static func readString(withMessage message: String) -> String {
        print(message)
        print("> ", terminator: "")
        let response = readLine() ?? ""
        return response
    }
    
    static func exitStonks(withMessage message: String, code: Int32 = 1) -> Never {
        print(message)
        exit(code)
    }
}
