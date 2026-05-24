import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section("数据") {
                    HStack {
                        Text("iCloud 同步")
                        Spacer()
                        Text("已启用")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("法律") {
                    NavigationLink("隐私政策") {
                        Text("隐私政策页面")
                            .navigationTitle("隐私政策")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        hasCompletedOnboarding = false
                    } label: {
                        Text("重置引导状态")
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
