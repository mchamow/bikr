import UIKit
import UserNotifications

/// Haptics plus a notification, so what happens on the track reaches a rider
/// whose phone is locked or in a pocket. Straying asks what to do about it,
/// right on the notification.
enum GuideAlerts {
    enum StrayChoice: String {
        /// Guide me back to the track.
        case backToTrack
        /// This was deliberate: stop following and record where I go.
        case newRoute
    }

    /// Answered from the notification; the app decides what it means.
    static var onStrayChoice: ((StrayChoice) -> Void)?

    private static let strayCategory = "stray"
    private static let coordinator = NotificationCoordinator()

    /// Call once at launch: notifications show while the app is open too, and
    /// the stray notification carries its two answers.
    static func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = coordinator
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: strayCategory,
                actions: [
                    UNNotificationAction(identifier: StrayChoice.backToTrack.rawValue, title: String(localized: "Back to Track")),
                    UNNotificationAction(identifier: StrayChoice.newRoute.rawValue, title: String(localized: "Track New Route")),
                ],
                intentIdentifiers: []
            ),
        ])
    }

    static func prepare() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    static func offTrack(by meters: Double) {
        notify(
            id: "track-status",
            title: String(localized: "Off track"),
            body: String(localized: "You're \(Format.distance(meters)) from the track. Head back, or keep going and record a new route?"),
            category: strayCategory
        )
        haptic(.warning)
    }

    static func backOnTrack() {
        notify(id: "track-status", title: String(localized: "Back on track"), body: String(localized: "Keep going."))
        haptic(.success)
    }

    static func finished(_ trackName: String) {
        notify(id: "track-finished", title: String(localized: "You made it"), body: String(localized: "You reached the end of \(trackName)."))
        haptic(.success)
    }

    private static func notify(id: String, title: String, body: String, category: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category { content.categoryIdentifier = category }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private static func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let choice = GuideAlerts.StrayChoice(rawValue: response.actionIdentifier) else { return }
        await MainActor.run {
            GuideAlerts.onStrayChoice?(choice)
        }
    }
}
