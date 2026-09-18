import BikrCore
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
        .alert("Unfinished Ride", isPresented: .constant(model.recoveredRide != nil)) {
            Button("Save Ride") { model.saveRecoveredRide() }
            Button("Discard", role: .destructive) { model.discardRecoveredRide() }
            // Without a cancel button SwiftUI adds its own, which would leave
            // the ride unresolved without saying so.
            Button("Decide Later", role: .cancel) {}
        } message: {
            if let ride = model.recoveredRide {
                Text("Bikr stopped while you were riding on \(ride.startedAt.formatted(date: .abbreviated, time: .shortened)). \(Format.distance(ride.stats.distance)) of it was recorded.")
            }
        }
        .alert(
            "Bikr",
            isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(model.message ?? "") }
        )
    }
}
