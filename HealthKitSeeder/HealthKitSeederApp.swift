import SwiftUI

@available(iOS 17.0, *)
@main
struct HealthKitSeederApp: App {
    @StateObject private var healthKitManager = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
        }
    }
}
