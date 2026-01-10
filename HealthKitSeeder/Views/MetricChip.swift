import SwiftUI

@available(iOS 17.0, *)
struct MetricChip: View {
    let reading: HealthMetricReading

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(reading.type.title, systemImage: reading.type.systemImage)
                .font(.caption)
                .foregroundStyle(.primary)
            Text(reading.displayText)
                .font(.headline.weight(.semibold))
            Text(labelSuffix)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var labelSuffix: String {
        switch reading.type {
        case .sleep:
            return "Asleep"
        case .timeInDaylight:
            return "Daylight minutes"
        case .steps:
            return "Total steps"
        case .distanceWalkingRunning:
            return "Walk/Run distance"
        case .distanceCycling:
            return "Cycling distance"
        case .distanceSwimming:
            return "Swim distance"
        case .activeEnergy:
            return "Energy burned"
        case .flightsClimbed:
            return "Flights climbed"
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    MetricChip(reading: .init(type: .steps, value: 8234))
}
