import UIKit
import UserNotifications

/// Haptics plus a notification, so alerts reach a rider whose phone is locked
/// or in a pocket.
enum GuideAlerts {
    private static let presenter = ForegroundPresenter()

    /// Call once at launch so alerts also show while the app is open.
    static func configure() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    static func requestPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    static func offTrack(by meters: Double) {
        notify(id: "track-status", title: "Off track", body: "You're \(Format.distance(meters)) away from the track.")
        haptic(.warning)
    }

    static func backOnTrack() {
        notify(id: "track-status", title: "Back on track", body: "Keep going.")
        haptic(.success)
    }

    static func finished(_ trackName: String) {
        notify(id: "track-finished", title: "You made it", body: "You reached the end of \(trackName).")
        haptic(.success)
    }

    private static func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private static func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
