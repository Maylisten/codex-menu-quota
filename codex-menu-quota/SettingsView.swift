import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var store: QuotaStore
    @State private var executablePath: String?

    var body: some View {
        Form {
            Section("通用") {
                Toggle("登录时自动启动", isOn: Binding(
                    get: { preferences.launchAtLogin },
                    set: { preferences.setLaunchAtLogin($0) }
                ))
                if let message = preferences.launchAtLoginError {
                    Text(message).font(.caption).foregroundStyle(.red)
                }

                Picker("自动刷新", selection: $preferences.refreshInterval) {
                    Text("15 秒").tag(15.0)
                    Text("30 秒").tag(30.0)
                    Text("1 分钟").tag(60.0)
                    Text("5 分钟").tag(300.0)
                }
            }

            Section("菜单栏显示") {
                Toggle("5 小时剩余额度", isOn: $preferences.showFiveHour)
                Toggle("每周剩余额度", isOn: $preferences.showWeekly)
                Toggle("可用重置次数", isOn: $preferences.showResetCount)
                Toggle("最近重置券到期时间", isOn: $preferences.showResetExpiry)
            }

            Section("数据来源") {
                LabeledContent("Codex 可执行文件") {
                    Text(executablePath ?? "未找到")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Text("应用通过 Codex 自带的本地 app-server 读取额度，不读取或保存登录令牌。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("立即刷新") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { executablePath = await store.executablePath() }
    }
}
