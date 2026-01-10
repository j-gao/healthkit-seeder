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
        let readTypes = Set(HealthMetric.allCases.compactMap { $0.shareType as? HKObjectType })

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
            fetch(metric: metric, within: interval) { value in
                aggregatedReadings.append(HealthMetricReading(type: metric, value: value))
                dispatchGroup.leave()
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

        if let sleepSample = mockSleepSample(for: interval) {
            objects.append(sleepSample)
        }

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
        } else if let categoryType = metric.categoryType {
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
            let query = HKSampleQuery(sampleType: categoryType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                let totalSeconds = samples?.compactMap { sample -> TimeInterval? in
                    guard let categorySample = sample as? HKCategorySample else { return nil }
                    guard asleepValues.contains(categorySample.value) else { return nil }

                    let overlapStart = max(interval.start, categorySample.startDate)
                    let overlapEnd = min(interval.end, categorySample.endDate)
                    let duration = overlapEnd.timeIntervalSince(overlapStart)
                    return duration > 0 ? duration : nil
                }.reduce(0, +) ?? 0

                let minutes = totalSeconds / 60
                DispatchQueue.main.async { completion(minutes) }
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

    private func mockSleepSample(for interval: DateInterval) -> HKCategorySample? {
        guard let sleepType = HealthMetric.sleep.categoryType else { return nil }

        let hours = Double.random(in: HealthMetric.sleep.mockRange)
        let duration = hours * 60 * 60
        let startDate = interval.start.addingTimeInterval(-TimeInterval.random(in: 3_600.0...7_200.0))
        let endDate = startDate.addingTimeInterval(duration)
        let metadata = [HKMetadataKeyWasUserEntered: true]

        return HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            start: startDate,
            end: endDate,
            metadata: metadata
        )
    }

    private func dayInterval(for date: Date) -> DateInterval {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}
