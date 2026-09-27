import GoogleMaps
import GoogleNavigation
import SwiftUI

struct LegalView: View {
    var body: some View {
        List {
            Section("Google Maps Platform") {
                Text("Bản đồ, tìm kiếm địa điểm và dữ liệu điều hướng được cung cấp bởi Google Maps Platform. Thuộc tính Google trên bản đồ không bị che hoặc thay đổi.")
                Link(
                    "Điều khoản Google Maps Platform",
                    destination: URL(string: "https://cloud.google.com/maps-platform/terms")!
                )
                Link(
                    "Chính sách quyền riêng tư Google",
                    destination: URL(string: "https://policies.google.com/privacy")!
                )
            }

            Section("Dữ liệu và quyền riêng tư") {
                Text("MiBand Navigator không có tài khoản người dùng, máy chủ riêng hoặc SDK phân tích. Ứng dụng không lưu lịch sử tọa độ. Google Maps Platform xử lý dữ liệu theo điều khoản và chính sách riêng của Google.")
            }

            Section("Giấy phép mã nguồn mở") {
                NavigationLink("Google Maps SDK") {
                    LicenseTextView(
                        title: "Google Maps SDK",
                        text: GMSServices.openSourceLicenseInfo()
                    )
                }
                NavigationLink("Google Navigation SDK") {
                    LicenseTextView(
                        title: "Google Navigation SDK",
                        text: GMSNavigationServices.openSourceLicenseInfo()
                    )
                }
            }
        }
        .navigationTitle("Pháp lý và quyền riêng tư")
    }
}

private struct LicenseTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
