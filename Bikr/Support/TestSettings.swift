import Foundation

/// Knobs the UI tests turn, so they can see behaviour that would otherwise
/// need airplane mode or half a minute of waiting.
///
/// Both an environment variable and a launch argument are read: a launch
/// argument is the tidier way to pass one, but the environment survives XCTest
/// relaunching the app after a failure, which a launch argument does not.
enum TestSettings {
    static var forcesOffline: Bool {
        environment("BIKR_FORCE_OFFLINE") == "1" || UserDefaults.standard.bool(forKey: "BikrForceOffline")
    }

    /// Seconds before a map the rider moved goes back to following them.
    static var returnToNavigation: TimeInterval? {
        if let seconds = environment("BIKR_RETURN_TO_NAVIGATION").flatMap(Double.init), seconds > 0 {
            return seconds
        }
        let fromArgument = UserDefaults.standard.double(forKey: "BikrReturnToNavigation")
        return fromArgument > 0 ? fromArgument : nil
    }

    private static func environment(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }
}
