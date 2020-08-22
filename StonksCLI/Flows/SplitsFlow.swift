struct SplitsFlow: Flow {
    let configFile: ConfigFile
    
    func run() {
        dumpSplits()
        Prompt.readString(withMessage: "Continue?")
        print()
    }
    
    private func dumpSplits() {
        print("Them's the splits")
        print()
    }
}
