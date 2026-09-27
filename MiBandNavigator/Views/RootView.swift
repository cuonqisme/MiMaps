import SwiftUI

struct RootView: View {
    @ObservedObject var environment: AppEnvironment

    var body: some View {
        TabView {
            NavigationStack {
                ContentView()
            }
            .tabItem { Label("Điều hướng", systemImage: "map") }

            NavigationStack {
                DeveloperToolsView(environment: environment)
            }
            .tabItem { Label("Công cụ", systemImage: "wrench.and.screwdriver") }

            NavigationStack {
                SettingsView(environment: environment)
            }
            .tabItem { Label("Cài đặt", systemImage: "gearshape") }
        }
    }
}

