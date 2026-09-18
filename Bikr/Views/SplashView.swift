import SwiftUI

/// What Bikr shows for the moment it takes to start: the icon's bicycle on the
/// icon's orange, so the app grows out of the icon that was tapped.
///
/// It never blocks anything — taps go straight through to the app behind it.
struct SplashView: View {
    /// How long the bicycle stays before the app fades in over it.
    static let visibleFor = Duration.milliseconds(850)
    static let fadeSeconds = 0.35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.sRGB, red: 1.00, green: 0.60, blue: 0.13),
                    Color(.sRGB, red: 0.93, green: 0.33, blue: 0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 18) {
                Image("SplashMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168, height: 168)
                    .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.86)

                Text("Bikr")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: hasAppeared || reduceMotion ? 0 : 10)
            }
            .opacity(hasAppeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.3)) {
                hasAppeared = true
            }
        }
    }
}
