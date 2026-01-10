import Foundation
import HealthKit

@available(iOS 17.0, *)
enum HealthMetric: String, CaseIterable, Identifiable {
    case sleep
    case timeInDaylight
    case steps
    case distanceWalkingRunning
    case distanceCycling
    case distanceSwimming
    case activeEnergy
    case flightsClimbed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .timeInDaylight: return "Time in Daylight"
        case .steps: return "Steps"
        case .distanceWalkingRunning: return "Walk + Run"
        case .distanceCycling: return "Cycling"
        case .distanceSwimming: return "Swimming"
        case .activeEnergy: return "Active Energy"
        case .flightsClimbed: return "Flights Climbed"
        }
    }

    var systemImage: String {
        switch self {
        case .sleep: return "moon.zzz.fill"
        case .timeInDaylight: return "sun.max.fill"
        case .steps: return "figure.walk.circle.fill"
        case .distanceWalkingRunning: return "figure.run.circle.fill"
        case .distanceCycling: return "bicycle.circle.fill"
        case .distanceSwimming: return "figure.pool.swim"
        case .activeEnergy: return "flame.fill"
        case .flightsClimbed: return "stairs"
        }
    }

    var quantityType: HKQuantityType? {
        switch self {
        case .sleep:
            return nil
        case .timeInDaylight:
            return HKQuantityType.quantityType(forIdentifier: .timeInDaylight)
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .distanceWalkingRunning:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .distanceCycling:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .distanceSwimming:
            return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        case .activeEnergy:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .flightsClimbed:
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        }
    }

    var categoryType: HKCategoryType? {
        switch self {
        case .sleep:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        default:
            return nil
        }
    }

    var shareType: HKSampleType? {
        quantityType ?? categoryType
    }

    var displayUnit: HKUnit? {
        switch self {
        case .sleep:
            return .minute()
        case .timeInDaylight:
            return .minute()
        case .steps, .flightsClimbed:
            return .count()
        case .activeEnergy:
            return .kilocalorie()
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming:
            return .meter()
        }
    }

    var displayOrder: Int {
        switch self {
        case .sleep: return 0
        case .timeInDaylight: return 1
        case .steps: return 2
        case .distanceWalkingRunning: return 3
        case .distanceCycling: return 4
        case .distanceSwimming: return 5
        case .activeEnergy: return 6
        case .flightsClimbed: return 7
        }
    }

    var mockRange: ClosedRange<Double> {
        switch self {
        case .sleep:
            return 6.5...8.5 // hours
        case .timeInDaylight:
            return 30...180 // minutes
        case .steps:
            return 4500...12000 // count
        case .distanceWalkingRunning:
            return 2500...9000 // meters
        case .distanceCycling:
            return 0...15000 // meters
        case .distanceSwimming:
            return 0...1200 // meters
        case .activeEnergy:
            return 350...950 // kilocalories
        case .flightsClimbed:
            return 4...24 // count
        }
    }

    func formattedValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        switch self {
        case .sleep:
            return Self.format(minutes: value)
        case .timeInDaylight:
            return Self.format(minutes: value)
        case .steps, .flightsClimbed:
            return Self.countFormatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
        case .activeEnergy:
            return "\(Self.decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)") kcal"
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming:
            let kilometers = value / 1000
            return "\(Self.decimalFormatter.string(from: NSNumber(value: kilometers)) ?? "\(kilometers)") km"
        }
    }

    private static func format(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private static var decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static var countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

@available(iOS 17.0, *)
enum SleepStage: String, CaseIterable, Identifiable {
    case awake
    case rem
    case core
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        }
    }

    var isAsleep: Bool {
        self != .awake
    }

    var healthKitValue: Int {
        switch self {
        case .awake:
            return HKCategoryValueSleepAnalysis.awake.rawValue
        case .rem:
            return HKCategoryValueSleepAnalysis.asleepREM.rawValue
        case .core:
            return HKCategoryValueSleepAnalysis.asleepCore.rawValue
        case .deep:
            return HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        }
    }

    init?(categoryValue: Int) {
        switch categoryValue {
        case HKCategoryValueSleepAnalysis.awake.rawValue,
             HKCategoryValueSleepAnalysis.inBed.rawValue:
            self = .awake
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            self = .rem
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            self = .deep
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
             HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            self = .core
        default:
            return nil
        }
    }

    static var legendOrder: [SleepStage] {
        [.deep, .core, .rem, .awake]
    }
}

@available(iOS 17.0, *)
struct SleepStageSegment: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let minutes: Double
}

@available(iOS 17.0, *)
struct SleepSummary {
    let segments: [SleepStageSegment]
    let startDate: Date
    let endDate: Date

    var totalMinutes: Double {
        segments.reduce(0) { $0 + $1.minutes }
    }

    var stageTotals: [SleepStage: Double] {
        var totals: [SleepStage: Double] = [:]
        for segment in segments {
            totals[segment.stage, default: 0] += segment.minutes
        }
        return totals
    }

    var asleepMinutes: Double {
        stageTotals.reduce(0) { partial, entry in
            entry.key.isAsleep ? partial + entry.value : partial
        }
    }
}

@available(iOS 17.0, *)
struct HealthMetricReading: Identifiable {
    let id = UUID()
    let type: HealthMetric
    let value: Double?
    let sleepSummary: SleepSummary?

    init(type: HealthMetric, value: Double?, sleepSummary: SleepSummary? = nil) {
        self.type = type
        self.value = value
        self.sleepSummary = sleepSummary
    }

    var displayText: String {
        type.formattedValue(value)
    }
}
