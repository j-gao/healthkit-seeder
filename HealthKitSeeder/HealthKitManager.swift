import Foundation
import HealthKit

@available(iOS 17.0, *)
@MainActor
final class HealthKitManager: ObservableObject {
    enum AuthorizationState {
        case unknown
        case authorized
        case denied
        case unavailable
    }

    @Published var readings: [HealthMetricReading] = []
    @Published var authorizationState: AuthorizationState = .unknown
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var statusMessage: String?
    @Published var selectedDate: Date = Date()

    private let healthStore = HKHealthStore()

    var isAuthorized: Bool { authorizationState == .authorized }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            statusMessage = "Health data is not available on this device."
            return
        }

        let shareTypes = Set(HealthMetric.allCases.compactMap { $0.shareType })
        let readTypes = Set(HealthMetric.allCases.compactMap { $0.shareType as HKObjectType? })

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if success {
                    self.authorizationState = .authorized
                    self.statusMessage = nil
                    self.refreshMetrics(for: self.selectedDate)
                } else {
                    self.authorizationState = .denied
                    self.statusMessage = error?.localizedDescription ?? "HealthKit authorization failed."
                }
            }
        }
    }

    func refreshMetrics(for date: Date) {
        guard isAuthorized else { return }

        isLoading = true
        statusMessage = nil

        let interval = dayInterval(for: date)
        let dispatchGroup = DispatchGroup()
        var aggregatedReadings: [HealthMetricReading] = []

        for metric in HealthMetric.allCases {
            dispatchGroup.enter()
            if metric == .sleep {
                fetchSleepSummary(within: interval) { summary in
                    aggregatedReadings.append(
                        HealthMetricReading(
                            type: metric,
                            value: summary?.asleepMinutes,
                            sleepSummary: summary
                        )
                    )
                    dispatchGroup.leave()
                }
            } else {
                fetch(metric: metric, within: interval) { value in
                    aggregatedReadings.append(HealthMetricReading(type: metric, value: value))
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.readings = aggregatedReadings.sorted { $0.type.displayOrder < $1.type.displayOrder }
            self.isLoading = false
        }
    }

    func generateMockData(for date: Date) {
        guard isAuthorized else {
            statusMessage = "Request HealthKit access before generating data."
            return
        }

        isGenerating = true
        statusMessage = nil

        let interval = dayInterval(for: date)
        var objects: [HKObject] = []

        let sleepSamples = mockSleepSamples(for: interval)
        objects.append(contentsOf: sleepSamples)

        if let daylightSample = mockQuantitySample(for: .timeInDaylight, on: interval) {
            objects.append(daylightSample)
        }

        if let stepsSample = mockQuantitySample(for: .steps, on: interval) {
            objects.append(stepsSample)
        }

        if let walkRunSample = mockQuantitySample(for: .distanceWalkingRunning, on: interval) {
            objects.append(walkRunSample)
        }

        if let cyclingSample = mockQuantitySample(for: .distanceCycling, on: interval) {
            objects.append(cyclingSample)
        }

        if let swimmingSample = mockQuantitySample(for: .distanceSwimming, on: interval) {
            objects.append(swimmingSample)
        }

        if let energySample = mockQuantitySample(for: .activeEnergy, on: interval) {
            objects.append(energySample)
        }

        if let flightsSample = mockQuantitySample(for: .flightsClimbed, on: interval) {
            objects.append(flightsSample)
        }

        guard !objects.isEmpty else {
            isGenerating = false
            statusMessage = "No mock data could be created."
            return
        }

        healthStore.save(objects) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isGenerating = false

                if success {
                    self.refreshMetrics(for: date)
                } else {
                    self.statusMessage = error?.localizedDescription ?? "Failed to save mocked data."
                }
            }
        }
    }

    private func fetch(metric: HealthMetric, within interval: DateInterval, completion: @escaping (Double?) -> Void) {
        if let quantityType = metric.quantityType, let unit = metric.displayUnit {
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                DispatchQueue.main.async { completion(value) }
            }
            healthStore.execute(query)
        } else {
            completion(nil)
        }
    }

    private func mockQuantitySample(for metric: HealthMetric, on interval: DateInterval) -> HKQuantitySample? {
        guard let quantityType = metric.quantityType, let unit = metric.displayUnit else { return nil }

        var rawValue = Double.random(in: metric.mockRange)
        if rawValue <= 0 { return nil }

        if metric == .sleep {
            // Sleep uses category samples; guard remains to avoid misrouting.
            return nil
        }

        if metric == .timeInDaylight || metric == .activeEnergy {
            rawValue.round(.toNearestOrAwayFromZero)
        } else {
            rawValue = round(rawValue)
        }

        let quantity = HKQuantity(unit: unit, doubleValue: rawValue)
        let startOffset = TimeInterval.random(in: 3_600.0...57_600.0)
        let duration = TimeInterval.random(in: 1_200.0...5_400.0)
        let startDate = interval.start.addingTimeInterval(startOffset)
        let endDate = min(startDate.addingTimeInterval(duration), interval.end)

        let metadata = [HKMetadataKeyWasUserEntered: true]
        return HKQuantitySample(type: quantityType, quantity: quantity, start: startDate, end: endDate, metadata: metadata)
    }

    private func fetchSleepSummary(within interval: DateInterval, completion: @escaping (SleepSummary?) -> Void) {
        guard let categoryType = HealthMetric.sleep.categoryType else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(
            sampleType: categoryType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var segments: [SleepStageSegment] = []
            var earliestStart: Date?
            var latestEnd: Date?

            for sample in categorySamples {
                guard let stage = SleepStage(categoryValue: sample.value) else { continue }

                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard duration > 0 else { continue }

                earliestStart = min(earliestStart ?? sample.startDate, sample.startDate)
                latestEnd = max(latestEnd ?? sample.endDate, sample.endDate)

                let minutes = duration / 60
                if let last = segments.last, last.stage == stage {
                    segments[segments.count - 1] = SleepStageSegment(
                        stage: stage,
                        minutes: last.minutes + minutes
                    )
                } else {
                    segments.append(SleepStageSegment(stage: stage, minutes: minutes))
                }
            }

            guard let start = earliestStart, let end = latestEnd, !segments.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let summary = SleepSummary(segments: segments, startDate: start, endDate: end)
            DispatchQueue.main.async { completion(summary) }
        }

        healthStore.execute(query)
    }

    private func mockSleepSamples(for interval: DateInterval) -> [HKCategorySample] {
        guard let sleepType = HealthMetric.sleep.categoryType else { return [] }

        let hours = Double.random(in: HealthMetric.sleep.mockRange)
        let totalMinutes = hours * 60
        let startOffset = TimeInterval.random(in: (-12_600.0)...(-7_200.0))
        let startDate = interval.start.addingTimeInterval(startOffset)
        let metadata = [HKMetadataKeyWasUserEntered: true]

        let segments = mergeAdjacentSegments(makeSleepSegments(totalMinutes: totalMinutes))
        guard !segments.isEmpty else { return [] }

        var samples: [HKCategorySample] = []
        var currentStart = startDate

        for segment in segments {
            let endDate = currentStart.addingTimeInterval(segment.minutes * 60)
            let sample = HKCategorySample(
                type: sleepType,
                value: segment.stage.healthKitValue,
                start: currentStart,
                end: endDate,
                metadata: metadata
            )
            samples.append(sample)
            currentStart = endDate
        }

        return samples
    }

    private func makeSleepSegments(totalMinutes: Double) -> [SleepStageSegment] {
        let cycleCount = max(3, min(5, Int((totalMinutes / 90.0).rounded())))
        let cycleMinutes = totalMinutes / Double(cycleCount)
        var segments: [SleepStageSegment] = []

        for index in 0..<cycleCount {
            let progress = Double(index) / Double(max(cycleCount - 1, 1))
            let deepShare = max(0.1, 0.24 - (0.1 * progress))
            let remShare = min(0.3, 0.12 + (0.12 * progress))
            let awakeShare = 0.03

            var deepMinutes = cycleMinutes * deepShare * Double.random(in: 0.85...1.1)
            var remMinutes = cycleMinutes * remShare * Double.random(in: 0.9...1.15)
            var awakeMinutes = cycleMinutes * awakeShare * Double.random(in: 0.6...1.3)

            deepMinutes = max(6, deepMinutes)
            remMinutes = max(6, remMinutes)
            awakeMinutes = max(2, awakeMinutes)

            var coreMinutes = cycleMinutes - deepMinutes - remMinutes - awakeMinutes
            if coreMinutes < 12 {
                coreMinutes = 12
                let overflow = (deepMinutes + remMinutes + awakeMinutes + coreMinutes) - cycleMinutes
                if overflow > 0 {
                    let adjustable = deepMinutes + remMinutes
                    if adjustable > 0 {
                        deepMinutes -= overflow * (deepMinutes / adjustable)
                        remMinutes -= overflow * (remMinutes / adjustable)
                    } else {
                        awakeMinutes = max(1, awakeMinutes - overflow)
                    }
                }
            }

            let coreFirst = coreMinutes * 0.45
            let coreSecond = coreMinutes - coreFirst

            segments.append(SleepStageSegment(stage: .core, minutes: coreFirst))
            segments.append(SleepStageSegment(stage: .deep, minutes: deepMinutes))
            segments.append(SleepStageSegment(stage: .core, minutes: coreSecond))
            segments.append(SleepStageSegment(stage: .rem, minutes: remMinutes))

            if index < cycleCount - 1 || Bool.random() {
                segments.append(SleepStageSegment(stage: .awake, minutes: awakeMinutes))
            }
        }

        segments.append(SleepStageSegment(stage: .awake, minutes: Double.random(in: 4...12)))

        let total = segments.reduce(0) { $0 + $1.minutes }
        let scale = totalMinutes / max(total, 1)
        return segments.map { SleepStageSegment(stage: $0.stage, minutes: $0.minutes * scale) }
    }

    private func mergeAdjacentSegments(_ segments: [SleepStageSegment]) -> [SleepStageSegment] {
        var merged: [SleepStageSegment] = []
        for segment in segments {
            if let last = merged.last, last.stage == segment.stage {
                merged[merged.count - 1] = SleepStageSegment(
                    stage: segment.stage,
                    minutes: last.minutes + segment.minutes
                )
            } else {
                merged.append(segment)
            }
        }
        return merged
    }

    private func dayInterval(for date: Date) -> DateInterval {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}
