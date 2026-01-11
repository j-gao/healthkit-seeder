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
            chipHeader(title: reading.type.title, systemImage: reading.type.systemImage)
            Text(reading.displayText)
                .font(.custom("Avenir Next", size: 18, relativeTo: .headline))
                .fontWeight(.semibold)
            Text(labelSuffix)
                .font(.custom("Avenir Next", size: 11, relativeTo: .caption2))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ChipPalette.cardStroke, lineWidth: 0.6)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    private func chipHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChipPalette.accent)
                .padding(6)
                .background(
                    Circle()
                        .fill(ChipPalette.iconBackground)
                )
            Text(title)
                .font(.custom("Avenir Next", size: 12, relativeTo: .caption))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
}

@available(iOS 17.0, *)
private struct SleepMetricChip: View {
    let reading: HealthMetricReading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chipHeader(title: reading.type.title, systemImage: reading.type.systemImage)
            Text(reading.displayText)
                .font(.custom("Avenir Next", size: 18, relativeTo: .headline))
                .fontWeight(.semibold)
            Text(timeRangeLabel)
                .font(.custom("Avenir Next", size: 11, relativeTo: .caption2))
                .foregroundStyle(.secondary)
            SleepStageBar(segments: reading.sleepSummary?.segments ?? [])
            if let summary = reading.sleepSummary {
                SleepStageLegend(summary: summary)
            } else {
                Text("No sleep stages recorded")
                    .font(.custom("Avenir Next", size: 11, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ChipPalette.cardStroke, lineWidth: 0.6)
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    private func chipHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChipPalette.accent)
                .padding(6)
                .background(
                    Circle()
                        .fill(ChipPalette.iconBackground)
                )
            Text(title)
                .font(.custom("Avenir Next", size: 12, relativeTo: .caption))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
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
        case .inBed:
            return Color(red: 0.60, green: 0.60, blue: 0.60)
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
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        )
    }
}

@available(iOS 17.0, *)
private struct SleepStageLegend: View {
    let summary: SleepSummary

    private var displayStages: [(stage: SleepStage, minutes: Double, percent: Int)] {
        let totals = summary.stageTotals
        let asleepMinutes = max(summary.asleepMinutes, 1)
        
        return SleepStage.legendOrder.compactMap { stage in
            let minutes = totals[stage] ?? 0
            guard minutes > 0 else { return nil }
            
            let percent: Int
            if stage == .awake {
                percent = Int(summary.awakePercent.rounded())
            } else {
                percent = Int((minutes / asleepMinutes * 100).rounded())
            }
            return (stage, minutes, percent)
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(displayStages, id: \.stage) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(SleepStageStyle.color(for: item.stage))
                        .frame(width: 10, height: 10)
                    Text("\(item.stage.title) \(formatMinutes(item.minutes)) | \(item.percent)%")
                        .font(.custom("Avenir Next", size: 11, relativeTo: .caption2))
                        .fontWeight(.semibold)
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

@available(iOS 17.0, *)
private enum ChipPalette {
    static let accent = Color(red: 0.16, green: 0.55, blue: 0.94)
    static let iconBackground = Color(red: 0.16, green: 0.55, blue: 0.94).opacity(0.18)
    static let cardStroke = Color.white.opacity(0.35)
}
