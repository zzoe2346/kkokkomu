import Foundation

@MainActor enum Preferences {
    static let defaults: UserDefaults = {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--data-dir"), args.count > index + 1 {
            let name = URL(fileURLWithPath: args[index + 1]).lastPathComponent
            return UserDefaults(suiteName: "com.zzoe.tail.qa." + name) ?? .standard
        }
        return .standard
    }()
}
