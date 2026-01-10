import SwiftUI

@available(iOS 17.0, *)
struct MetricChip: View {
    let reading: HealthMetricReading

    var body: some View {
        if reading.type == .sleep {
            SleepMetricChip(reading: reading)
        } else {
            standardChip
        }
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

    private var standardChip: some View {
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
}

@available(iOS 17.0, *)
private struct SleepMetricChip: View {
    let reading: HealthMetricReading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(reading.type.title, systemImage: reading.type.systemImage)
                .font(.caption)
                .foregroundStyle(.primary)
            Text(reading.displayText)
                .font(.headline.weight(.semibold))
            Text(timeRangeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            SleepStageBar(segments: reading.sleepSummary?.segments ?? [])
            if let summary = reading.sleepSummary {
                SleepStageLegend(summary: summary)
            } else {
                Text("No sleep stages recorded")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var timeRangeLabel: String {
        guard let summary = reading.sleepSummary else { return "Asleep | --" }
        let start = Self.timeFormatter.string(from: summary.startDate)
        let end = Self.timeFormatter.string(from: summary.endDate)
        return "Asleep | \(start) - \(end)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

@available(iOS 17.0, *)
private struct SleepStageStyle {
    static func color(for stage: SleepStage) -> Color {
        switch stage {
        case .deep:
            return Color(red: 0.42, green: 0.36, blue: 0.85)
        case .core:
            return Color(red: 0.39, green: 0.58, blue: 0.90)
        case .rem:
            return Color(red: 0.18, green: 0.72, blue: 0.69)
        case .awake:
            return Color(red: 0.95, green: 0.62, blue: 0.30)
        }
    }
}

@available(iOS 17.0, *)
private struct SleepStageBar: View {
    let segments: [SleepStageSegment]

    var body: some View {
        GeometryReader { proxy in
            let total = max(segments.reduce(0) { $0 + $1.minutes }, 1)
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    Rectangle()
                        .fill(SleepStageStyle.color(for: segment.stage))
                        .frame(width: proxy.size.width * (segment.minutes / total))
                }
            }
        }
        .frame(height: 12)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

@available(iOS 17.0, *)
private struct SleepStageLegend: View {
    let summary: SleepSummary

    var body: some View {
        let totals = summary.stageTotals
        let totalMinutes = max(summary.totalMinutes, 1)
        let stages = SleepStage.legendOrder.filter { (totals[$0] ?? 0) > 0 }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(stages) { stage in
                let minutes = totals[stage, default: 0]
                let percent = Int((minutes / totalMinutes * 100).rounded())
                HStack(spacing: 6) {
                    Circle()
                        .fill(SleepStageStyle.color(for: stage))
                        .frame(width: 10, height: 10)
                    Text("\(stage.title) \(formatMinutes(minutes)) | \(percent)%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

@available(iOS 17.0, *)
struct MetricChip_Previews: PreviewProvider {
    static var previews: some View {
        MetricChip(reading: .init(type: .steps, value: 8234))
    }
}
