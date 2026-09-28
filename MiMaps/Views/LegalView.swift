import SwiftUI

struct LegalView: View {
    var body: some View {
        List {
            Section("Apple Maps") {
                Text("Bản đồ, tìm kiếm địa điểm và dữ liệu tuyến đường được cung cấp bởi Apple MapKit.")
                Link(
                    "Điều khoản Apple Maps",
                    destination: URL(string: "https://www.apple.com/legal/internet-services/maps/terms-en.html")!
                )
                Link(
                    "Chính sách quyền riêng tư Apple",
                    destination: URL(string: "https://www.apple.com/legal/privacy/")!
                )
            }

            Section("Dữ liệu và quyền riêng tư") {
                Text("MiMaps không có tài khoản người dùng, máy chủ riêng hoặc SDK phân tích. Ứng dụng không lưu lịch sử tọa độ. MapKit xử lý yêu cầu tìm kiếm và tuyến đường theo điều khoản của Apple.")
            }

            Section("Mi Band") {
                Text("Chỉ dẫn được gửi bằng thông báo cục bộ của iOS và phản chiếu qua Mi Fitness. Ứng dụng không kết nối trực tiếp tới thiết bị bằng giao thức BLE riêng của Xiaomi.")
            }
        }
        .navigationTitle("Pháp lý và quyền riêng tư")
    }
}
