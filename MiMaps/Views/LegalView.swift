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
                Text("MiMaps có thể kết nối Bluetooth trực tiếp với Xiaomi Smart Band. Khóa ghép đôi chỉ được lưu trong Keychain trên iPhone. Band Lab yêu cầu người dùng chủ động bắt đầu xác thực và không tự reset, hủy ghép đôi hoặc cài firmware.")
            }

            Section("Thư viện mã nguồn mở") {
                Text("MiMaps dùng CryptoSwift để thực hiện AES-CCM trong bước xác thực thiết bị.")
                Link(
                    "CryptoSwift — giấy phép và mã nguồn",
                    destination: URL(string: "https://github.com/krzyzanowskim/CryptoSwift")!
                )
            }
        }
        .navigationTitle("Pháp lý và quyền riêng tư")
    }
}
