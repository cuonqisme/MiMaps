import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("MiBand Navigator")
                    .font(.largeTitle.bold())

                Text("Điều hướng trên iPhone, chỉ dẫn ngắn gọn trên Mi Band.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Trang chủ")
        }
    }
}

#Preview {
    ContentView()
}

