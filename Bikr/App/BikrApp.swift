import SwiftUI

@main
struct BikrApp: App {
    @State private var model = AppModel()

    init() {
        GuideAlerts.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
