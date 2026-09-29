import Foundation

public enum ShowSoundSupport {
    public static let ownerName = "Naor Yanko"
    public static let ownerEmail = "na0ryank0@gmail.com"
    public static let repo = "rept0rix/show-sound"
    public static let websiteURL = URL(string: "https://rept0rix.github.io/show-sound/")!
    public static let downloadURL = URL(string: "https://github.com/rept0rix/show-sound/releases/latest")!
    public static let donateURL = URL(string: "https://buymeacoffee.com/na0ryank0r")!

    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" // showsound-version
    }
}
