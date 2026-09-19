import Foundation

/// Human-readable values in the rider's units (km or miles, per region).
enum Format {
    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters).formatted(
            .measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0...1)))
        )
    }

    static func speed(_ metersPerSecond: Double) -> String {
        Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond).formatted(
            .measurement(width: .abbreviated, usage: .general, numberFormatStyle: .number.precision(.fractionLength(1)))
        )
    }

    static func elevation(_ meters: Double) -> String {
        let usesFeet = Locale.current.measurementSystem == .us
        let value = Measurement(value: meters, unit: UnitLength.meters).converted(to: usesFeet ? .feet : .meters)
        return value.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    /// A gap in a race: "0:12".
    static func gap(_ seconds: TimeInterval) -> String {
        Duration.seconds(abs(seconds).rounded()).formatted(.time(pattern: .minuteSecond))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, seconds.rounded(.down))).formatted(.time(pattern: .hourMinuteSecond))
    }
}
