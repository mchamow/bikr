import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("Ride", systemImage: "bicycle", value: .ride) {
                RideScreen()
            }
            Tab("Tracks", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath", value: .tracks) {
                TracksScreen()
            }
        }
        // GPX files opened from Files, Mail, Safari, AirDrop...
        .onOpenURL { model.importGPX(from: [$0]) }
        .alert(
            "Bikr",
            isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(model.message ?? "") }
        )
    }
}
