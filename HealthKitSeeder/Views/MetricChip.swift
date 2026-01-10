import SwiftUI

@available(iOS 17.0, *)
struct MetricChip: View {
    let reading: HealthMetricReading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(reading.type.title, systemImage: reading.type.systemImage)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(reading.displayText)
                .font(.title2.weight(.semibold))
            Text(labelSuffix)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
