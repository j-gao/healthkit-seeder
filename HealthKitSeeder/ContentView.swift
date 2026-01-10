import SwiftUI

@available(iOS 17.0, *)
struct ContentView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isShowingDatePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        datePickerSection

                        if healthKitManager.authorizationState != .authorized {
                            PermissionCard(
                                statusMessage: healthKitManager.statusMessage,
                                action: healthKitManager.requestAuthorization
                            )
                        } else {
                            metricsSection
                        }

                        if let status = healthKitManager.statusMessage, !status.isEmpty {
                            Text(status)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                if isShowingDatePicker {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.easeInOut) { isShowingDatePicker = false }
                        }

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pick a date")
                                    .font(.headline)
                                Text("Updates the metrics and generator range.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                withAnimation(.easeInOut) { isShowingDatePicker = false }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Close date picker")
                        }
                        .padding()

                        Divider()

                        DatePicker(
                            "Date",
                            selection: $healthKitManager.selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .onChange(of: healthKitManager.selectedDate) { newValue in
                            if healthKitManager.isAuthorized {
                                healthKitManager.refreshMetrics(for: newValue)
                            }
                            withAnimation(.easeInOut) {
                                isShowingDatePicker = false
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: 500)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 10)
                    )
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .onAppear {
                if healthKitManager.authorizationState == .unknown {
                    healthKitManager.requestAuthorization()
                } else if healthKitManager.isAuthorized {
                    healthKitManager.refreshMetrics(for: healthKitManager.selectedDate)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isShowingDatePicker)
        }
    }

    private var datePickerSection: some View {
        HStack(spacing: 12) {
            Button {
                isShowingDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                    Text(selectedDateLabel)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            if healthKitManager.isAuthorized {
                Button {
                    healthKitManager.refreshMetrics(for: healthKitManager.selectedDate)
                } label: {
                    if healthKitManager.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(healthKitManager.isLoading)
                .accessibilityLabel("Refresh data")
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(healthKitManager.readings) { reading in
                    MetricChip(reading: reading)
                }
            }

            Button {
                healthKitManager.generateMockData(for: healthKitManager.selectedDate)
            } label: {
                HStack {
                    if healthKitManager.isGenerating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(healthKitManager.isGenerating ? "Writing..." : "Generate Mock Data")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "sparkles")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(healthKitManager.isGenerating)
            .animation(.easeInOut(duration: 0.2), value: healthKitManager.isGenerating)
        }
    }

    private var selectedDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: healthKitManager.selectedDate)
    }
}

@available(iOS 17.0, *)
private struct PermissionCard: View {
    let statusMessage: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allow Health Access")
                .font(.headline)
            Text("Grant read and write access for sleep, daylight, steps, distances, energy, and flights so we can inspect and seed realistic data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Request HealthKit Access", action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

@available(iOS 17.0, *)
#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
