import SwiftUI

@available(iOS 17.0, *)
struct ContentView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isShowingDatePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                ambientBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
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
                                .font(.custom("Avenir Next", size: 14, relativeTo: .callout))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .scrollIndicators(.hidden)

                if isShowingDatePicker {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.smooth) { isShowingDatePicker = false }
                        }

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pick a date")
                                    .font(.custom("Avenir Next", size: 18, relativeTo: .headline))
                                    .fontWeight(.semibold)
                                Text("Updates the metrics and generator range.")
                                    .font(.custom("Avenir Next", size: 12, relativeTo: .caption))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                withAnimation(.smooth) { isShowingDatePicker = false }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
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
                        .tint(ModernPalette.accent)
                        .onChange(of: healthKitManager.selectedDate) { _, newValue in
                            if healthKitManager.isAuthorized {
                                healthKitManager.refreshMetrics(for: newValue)
                            }
                            withAnimation(.smooth) {
                                isShowingDatePicker = false
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: 500)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(ModernPalette.cardStroke, lineWidth: 0.6)
                            )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 18)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HealthKit Seeder")
                .font(.custom("Avenir Next", size: 30, relativeTo: .title2))
                .fontWeight(.semibold)
            Text("Seed, inspect, and refresh daily metrics with a single tap.")
                .font(.custom("Avenir Next", size: 14, relativeTo: .subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var datePickerSection: some View {
        ModernCard {
            HStack(spacing: 12) {
                Button {
                    isShowingDatePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ModernPalette.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Selected date")
                                .font(.custom("Avenir Next", size: 11, relativeTo: .caption2))
                                .foregroundStyle(.secondary)
                            Text(selectedDateLabel)
                                .font(.custom("Avenir Next", size: 14, relativeTo: .subheadline))
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.22))
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                if healthKitManager.isAuthorized {
                    Button {
                        healthKitManager.generateMockData(for: healthKitManager.selectedDate)
                    } label: {
                        HStack(spacing: 6) {
                            if healthKitManager.isGenerating {
                                ProgressView()
                                    .tint(.white)
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(healthKitManager.isGenerating ? "Writing..." : "Generate")
                                .font(.custom("Avenir Next", size: 12, relativeTo: .caption))
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            LinearGradient(
                                colors: [ModernPalette.accent, ModernPalette.accentGlow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule(style: .continuous))
                        .shadow(color: ModernPalette.accent.opacity(0.3), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(healthKitManager.isGenerating)
                    .accessibilityLabel("Generate mock data")

                    Button {
                        healthKitManager.refreshMetrics(for: healthKitManager.selectedDate)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(ModernPalette.accent.opacity(0.15))
                            if healthKitManager.isLoading {
                                ProgressView()
                                    .tint(ModernPalette.accent)
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(ModernPalette.accent)
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(healthKitManager.isLoading)
                    .accessibilityLabel("Refresh data")
                }
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.custom("Avenir Next", size: 13, relativeTo: .subheadline))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if let sleepReading = healthKitManager.readings.first(where: { $0.type == .sleep }) {
                MetricChip(reading: sleepReading)
            }

            let otherReadings = healthKitManager.readings.filter { $0.type != .sleep }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(otherReadings) { reading in
                    MetricChip(reading: reading)
                }
            }
        }
    }

    private var ambientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [ModernPalette.backgroundTop, ModernPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(ModernPalette.accentGlow.opacity(0.18))
                .frame(width: 320, height: 320)
                .offset(x: 160, y: -220)
                .blur(radius: 10)
            Circle()
                .fill(ModernPalette.accent.opacity(0.12))
                .frame(width: 240, height: 240)
                .offset(x: -140, y: 240)
                .blur(radius: 8)
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
private enum ModernPalette {
    static let accent = Color(red: 0.16, green: 0.55, blue: 0.94)
    static let accentGlow = Color(red: 0.42, green: 0.78, blue: 1.0)
    static let backgroundTop = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let backgroundBottom = Color(red: 0.92, green: 0.95, blue: 0.99)
    static let cardStroke = Color.white.opacity(0.35)
}

@available(iOS 17.0, *)
private struct ModernCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ModernPalette.cardStroke, lineWidth: 0.6)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
}

@available(iOS 17.0, *)
private struct PermissionCard: View {
    let statusMessage: String?
    let action: () -> Void

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Allow Health Access")
                    .font(.custom("Avenir Next", size: 18, relativeTo: .headline))
                    .fontWeight(.semibold)
                Text("Grant read and write access for sleep, daylight, steps, distances, energy, and flights so we can inspect and seed realistic data.")
                    .font(.custom("Avenir Next", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)

                if let statusMessage, !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.custom("Avenir Next", size: 12, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                }

                Button("Request HealthKit Access", action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(ModernPalette.accent)
            }
        }
    }
}

@available(iOS 17.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(HealthKitManager())
    }
}
